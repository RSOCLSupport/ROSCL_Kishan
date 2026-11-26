# Mass Records Approval – Security Review False Positives

Package: Mass Records Approval (namespace `massapprv`), version 1.1.0 (ancestor: released 1.0.0.5, `04tdM000000eyYXQAY`).
Scanners, run on 26 Nov 2026 over `force-app` only:

- Salesforce Code Analyzer 5, rule selectors `AppExchange`, `Recommended:Security` and `sfge`: 7 findings (sections 1 to 3).
- ApexGuru (`--rule-selector apexguru --target-org rsoclDevHub`, BASIC mode): 8 findings (section 4). These are
  performance and code-quality rules, not security rules.

All other findings from these rule sets were fixed. The seven Code Analyzer findings below remain, and all are in
`RSOCL_MockDaoProcessInstanceController` (the package's data-access class; it is the real DAO, the "Mock" in its name is historical).

The repository also contains an untracked folder `Bulk Records Approval App/`, an old backup copy of the project that is
not part of the package. Scans must use `--workspace force-app`; scanning the repository root reports that folder's
outdated classes as well.

## 1. ApexFlsViolation – `ProcessInstance` sub-queries on `WorkItems` and `Steps` (2 findings)

Method: `getProcessInstance(String stepStatus, Id lastActorId)`, used only by the Admin View.

- `ProcessInstance`, `ProcessInstanceWorkitem` and `ProcessInstanceStep` are system objects that expose approval history.
  They have no customizable field-level security; their visibility is controlled by the approval process and record access.
- The fields read (`Actor.Name`, `OriginalActor.Name`, `Comments`, `StepStatus`, `SystemModstamp`) are the same ones
  Salesforce shows in the standard Approval History related list.
- The Admin View tab is granted only by the `Admin_Access_to_Mass_Approval_Product` permission set.
- Record fields shown next to each request are queried separately and pass through
  `Security.stripInaccessible(AccessType.READABLE, ...)`, so a user never sees the value of a field they cannot read
  (the label is shown with "No Data Present"; verified 26 Nov 2026 with a Standard User).

## 2. AvoidDatabaseOperationInLoop – `getSObjectMap` (3 findings)

Called from `querySObjects` in `RSOCL_MultipleApprovalController`, `RSOCL_ApprovalProcessedDataController` and `RSOCL_AdminViewController`.

- Pending approvals can belong to several object types, and SOQL cannot query several objects in one statement,
  so the code runs **one query per object type** (not per record). Record ids are bound with `IN :ids`.
- The loop is bounded: it stops when `Limits.getQueries()` reaches 100.
- The object and field names used in these dynamic queries are first checked against the org schema by
  `RSOCL_SchemaUtil` (`isValidObject` / `validFields`), so no unvalidated text reaches the query.

## 3. MissingNullCheckOnSoqlVariable (2 findings)

**`lastActorId`** in `getProcessInstance(String stepStatus, Id lastActorId)`, entry point `RSOCL_AdminViewController`:

- `null` is passed on purpose: `WHERE LastActorId = null` selects approval requests that no approver has acted on yet.
  It is a bind variable, so it cannot change the query structure.

**`objectName`** in `getApprovalDataSettings(String objectName)`, entry point `RSOCL_ApprovalDataSettingController.saveApproveSettings`:

- The method returns an empty list when `objectName` is null or blank, before the query runs.
- On this path `saveApproveSettings` has already rejected a null or unknown object through
  `RSOCL_SchemaUtil.validFields`, so the query is never reached with null. The scanner does not follow either guard
  across the DAO interface call. In any case it is a bind variable.

## 4. ApexGuru findings (8, performance and code quality)

These were reviewed and deliberately left unchanged in this version, so the application's behavior stays identical.
None of them is a security issue.

### 4.1 SchemaGetGlobalDescribeNotEfficient (5 findings, High)

| Location                                       | Use                                                                                      |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `RSOCL_MultipleApprovalController.cls:14`      | Static map; used for the object label (`relatedTo`) and field labels of displayed fields |
| `RSOCL_ApprovalProcessedDataController.cls:14` | Same pattern as above                                                                    |
| `RSOCL_AdminViewController.cls:11`             | Same pattern as above                                                                    |
| `RSOCL_ApprovalDataSettingController.cls:54`   | `getFields(objectName)`: lists the fields of the object chosen on the setup screen       |
| `RSOCL_SchemaUtil.cls:6`                       | Static map; validates object and field names before they are saved or queried            |

- `Schema.getGlobalDescribe()` is called at most once per class per transaction (static initializer or once per
  method call), never inside a loop. Per-object field maps are additionally cached in `fieldMapCache`.
- The object names involved are dynamic (any object with an active approval process in the subscriber org), which is
  why a global describe is used for lookup and validation.
- Replacing it with per-object describes is a performance optimization planned for a later version; it does not affect
  security or data access.

### 4.2 SoqlWithApexFilter and SoqlWithoutAWhereClauseOrLimitStatement (2 findings, Moderate and Low)

`RSOCL_ExceptionLoggerTest.cls:33-34`: a test-only query on `Exception_Logger__c`. Test data is isolated, so the
query only sees the single record the test itself creates, and the test asserts exactly one row. It is not packaged
application logic and runs only during Apex tests.

### 4.3 SoqlWithNegativeExpressions (1 finding, Low)

`RSOCL_MockDaoProcessInstanceController.cls:184`, method `getProcessInstance(userId, delegateUserSet, setOfGroupIds, lastActorId)`,
used by the Recently Approved/Rejected tab: `WHERE LastActorId != :lastActorId` with `lastActorId = null` selects approval
requests that an approver has already acted on. The sub-query further limits rows to Approved or Rejected steps of the
current user, their delegators or their groups, from the last 7 days. Rewriting the condition would change which
records appear, so it is intentional.

## Other security measures in this version

- All Apex classes are `with sharing`; there is no `without sharing` and no `global` Apex.
- The two permission sets grant Apex class access only to the controllers their screens call: General User to
  `RSOCL_MultipleApprovalController` and `RSOCL_ApprovalProcessedDataController`; Admin to those two plus
  `RSOCL_AdminViewController` and `RSOCL_ApprovalDataSettingController`.
- Settings are read `WITH USER_MODE`; settings and error logs are inserted with `AccessLevel.USER_MODE`.
- Object and field names entered on the setup screen are validated against the schema before they are saved.
- Errors are logged to `Exception_Logger__c`; users see only a generic message.
- Org-wide sharing: `Exception_Logger__c` is Private, `Approval_Data_Setting__c` is Public Read Only.
- No callouts, Remote Site Settings, Named Credentials or external endpoints.
- Static resource `Bootstrap5` contains only Bootstrap 5.0.2 CSS; no third-party JavaScript is loaded.
