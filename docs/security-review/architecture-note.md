# Mass Records Approval (Let's Approve) – Architecture Note

Package: Mass Records Approval, managed 2GP, namespace `massapprv`. Apex API 66.0; LWC and Aura API 67.0.

The app is a set of Lightning pages over **standard Salesforce approval processes**. It reads pending approval
requests, shows them with fields chosen by an administrator, and approves or rejects them through the standard
`Approval.process` API. It runs entirely inside the subscriber org: there are **no callouts, no Remote Site Settings,
no Named Credentials and no external endpoints**.

## Components

### Lightning components (UI)

| Component                                                               | Tab                        | Apex it calls                                                                          |
| ----------------------------------------------------------------------- | -------------------------- | -------------------------------------------------------------------------------------- |
| `massApprovalComponent` (LWC)                                           | Approval Request           | `RSOCL_MultipleApprovalController.getSubmittedApprovalRecords`, `.processRecords`      |
| `recentlyApprovedComp` (LWC)                                            | Recently Approved/Rejected | `RSOCL_ApprovalProcessedDataController.getProcessedAprrovalRecords`                    |
| `adminViewComponent` (LWC)                                              | Admin View                 | `RSOCL_AdminViewController.getSubmittedApprovalRecordsByAllUsers`                      |
| `approvalDataSettingComp` (LWC)                                         | inside the Setup tab       | `RSOCL_ApprovalDataSettingController.getObjects`, `.getFields`, `.saveApproveSettings` |
| `setupInstructionComponent` (LWC)                                       | Setup                      | none (embeds `assignPermissionSetComp` and `approvalDataSettingComp`)                  |
| `assignPermissionSetComp` (LWC)                                         | inside the Setup tab       | none (instructions only)                                                               |
| `ParentApprovalDataSettingComp`, `ParentAssignPermissionSetComp` (Aura) | —                          | none; thin wrappers around the LWCs                                                    |

### Apex classes

| Class                                              | Role                                                                                                                                                                                                                                                                                            |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RSOCL_MultipleApprovalController`                 | Pending requests for the current user (directly, through a queue or public group, or as delegated approver); bulk approve/reject                                                                                                                                                                |
| `RSOCL_ApprovalProcessedDataController`            | Requests the current user approved or rejected in the last 7 days                                                                                                                                                                                                                               |
| `RSOCL_AdminViewController`                        | Pending requests across all users (admin screen)                                                                                                                                                                                                                                                |
| `RSOCL_ApprovalDataSettingController`              | Lists objects with an active approval process and their fields; saves the field settings                                                                                                                                                                                                        |
| `RSOCL_MockDaoProcessInstanceController`           | Data-access layer (the "Mock" in the name is historical): all queries on `ProcessDefinition`, `ProcessInstance` and `Approval_Data_Setting__c`, plus the dynamic query for displayed fields. Implements the interface `IProcessDefination`, so tests can substitute an in-memory implementation |
| `RSOCL_SchemaUtil`                                 | Validates object and field names against the org schema                                                                                                                                                                                                                                         |
| `RSOCL_ExceptionLogger`                            | Writes errors to `Exception_Logger__c` and builds the generic error returned to the UI                                                                                                                                                                                                          |
| `*Test`, `RSOCL_MockProcessInstanceControllerTest` | Test classes and the test-only data-access mock (`@IsTest`)                                                                                                                                                                                                                                     |

### Data objects

| Object                     | Fields                                                                                                                        | Purpose                                                                                                                    |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `Approval_Data_Setting__c` | `Object_API_name__c` (Text 200, required), `Approval_Fields__c` (Long Text Area 32,768)                                       | One record per object: which fields to show next to that object's approval requests. Org-wide default **Public Read Only** |
| `Exception_Logger__c`      | `Class_Name__c`, `Function_Name__c`, `Error_Line_Number__c`, `Error_Message__c`, `Error_Type__c`, `Additional_Information__c` | Error log for administrators. Org-wide default **Private**                                                                 |

Standard objects read: `ProcessDefinition`, `ProcessInstance` (with `WorkItems` and `Steps`), `User`, `GroupMember`,
and the records under approval (any object with an active approval process).

## Data flow

**Approval Request tab (pending requests)**

1. `RSOCL_MultipleApprovalController` finds users who named the current user as Delegated Approver (`User`, `WITH USER_MODE`)
   and the queues/groups of the current user and those users (`GroupMember`, `WITH USER_MODE`).
2. The data-access class reads `ProcessInstance` records with their work items assigned to any of them.
3. The field settings are read from `Approval_Data_Setting__c` (`WITH USER_MODE`). Every object and field name is
   checked by `RSOCL_SchemaUtil`; unknown names are dropped.
4. For each object type, one dynamic query reads the configured fields of the records under approval
   (`Database.queryWithBinds`, record ids bound with `IN :ids`). Values of fields the user cannot read are removed with
   `Security.stripInaccessible(AccessType.READABLE, …)`: their value is never sent to the browser, and the field's
   label is shown with "No Data Present".
5. The results are returned to the LWC as wrapper objects.

**Approve / Reject**

`processRecords` receives work item ids and comments, builds `Approval.ProcessWorkitemRequest` objects and calls
`Approval.process(requests, false)`. Salesforce's approval engine checks that the user may act on each work item, records
the decision and comment in Approval History, and runs the process's own actions. Each request succeeds or fails on its
own; failures are returned as messages.

**Recently Approved/Rejected and Admin View** follow the same steps 2–5 with their own `ProcessInstance` queries
(steps approved or rejected by the user in the last 7 days; pending requests of all users whose work item changed in
the last 7 days).

**Setup (field settings)**

`getObjects` lists objects with an active approval process (`ProcessDefinition`); `getFields` describes the chosen
object's fields; `saveApproveSettings` validates the object and every field name with `RSOCL_SchemaUtil` (rejecting
anything unknown), then inserts the setting with `AccessLevel.USER_MODE`.

## Security model

- **Sharing:** every Apex class is `with sharing`. There is no `without sharing` and no `global` Apex.
- **CRUD/FLS:**
  - settings queries run `WITH USER_MODE`;
  - inserts of settings and error logs use `AccessLevel.USER_MODE`;
  - record fields shown to the user pass through `Security.stripInaccessible(AccessType.READABLE, …)`;
  - the one explicit `SYSTEM_MODE` query (records under approval) exists so an approver can see requests on records
    they would not otherwise reach; it is limited to the ids of their own approval requests, and its fields are
    stripped as above.
- **Injection:** object and field names used in dynamic SOQL come only from `Approval_Data_Setting__c` and are validated
  by `RSOCL_SchemaUtil` against the schema before saving and again before every query. Record ids are bind variables.
- **Errors:** controllers catch exceptions, log them with `RSOCL_ExceptionLogger`, and return a generic message to the
  user, without internal details.
- **Access:** the two permission sets grant Apex class access only to the controllers their tabs use.
- **Client side:** no `eval`, no `innerHTML`, no third-party JavaScript. See `third-party-libraries.md`.
- **Known scanner findings:** see `false-positives.md`.
