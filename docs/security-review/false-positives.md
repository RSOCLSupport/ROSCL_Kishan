# Mass Records Approval – Security Review False Positives

Package: Mass Records Approval (namespace `massapprv`), released version 1.0.0.5 (`04tdM000000eyYXQAY`).
Scanner: Salesforce Code Analyzer 5 with rule selectors `AppExchange`, `Recommended:Security` and `sfge`, run over `force-app`.

All other findings from these rule sets were fixed. The seven findings below remain, and all are in
`RSOCL_MockDaoProcessInstanceController` (the package's data-access class; it is the real DAO, the "Mock" in its name is historical).

## 1. ApexFlsViolation – `ProcessInstance` sub-queries on `WorkItems` and `Steps` (2 findings)

Method: `getProcessInstance(String stepStatus, Id lastActorId)`, used only by the Admin View.

- `ProcessInstance`, `ProcessInstanceWorkitem` and `ProcessInstanceStep` are system objects that expose approval history.
  They have no customizable field-level security; their visibility is controlled by the approval process and record access.
- The fields read (`Actor.Name`, `OriginalActor.Name`, `Comments`, `StepStatus`, `SystemModstamp`) are the same ones
  Salesforce shows in the standard Approval History related list.
- The Admin View tab is granted only by the `Admin_Access_to_Mass_Approval_Product` permission set.
- Record fields shown next to each request are queried separately and pass through
  `Security.stripInaccessible(AccessType.READABLE, ...)`, so a user never sees a field they cannot read.

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

## Other security measures in this version

- All Apex classes are `with sharing`; there is no `without sharing` and no `global` Apex.
- Settings are read `WITH USER_MODE`; settings and error logs are inserted with `AccessLevel.USER_MODE`.
- Object and field names entered on the setup screen are validated against the schema before they are saved.
- Errors are logged to `Exception_Logger__c`; users see only a generic message.
- Org-wide sharing: `Exception_Logger__c` is Private, `Approval_Data_Setting__c` is Public Read Only.
- No callouts, Remote Site Settings, Named Credentials or external endpoints.
- Static resource `Bootstrap5` contains only Bootstrap 5.0.2 CSS; no third-party JavaScript is loaded.
