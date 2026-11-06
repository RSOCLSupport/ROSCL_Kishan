# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Salesforce DX project for a "Mass/Bulk Records Approval" app: users see every approval request pending on them (directly, as a delegated approver, or through a queue/group they belong to), across any object, and approve or reject them in bulk. Admins pick which fields of each object appear next to the request. It is packaged as the **managed 2GP** package `Mass Records Approval` (ID `0HodM0000006SODSA2`, namespace `massapprv`, Dev Hub alias `vscodeOrg`). API version is 67.0.

Apex classes are pinned to API **66.0** on purpose (LWC/Aura are 67.0). From API 67.0 Apex runs in user mode by default, which breaks the DAO's system-mode reads and the tests; moving to 67.0 needs a deliberate redesign. Don't go to 59.0 or lower either: Code Analyzer's AppExchange rules flag it.

Version 1.0.0.5 (`04tdM000000eyYXQAY`) is **released**; `sfdx-project.json` now builds 1.1.0 with `ancestorVersion: HIGHEST`. Released components are permanent: don't rename or delete packaged objects, fields or other API names. Known scanner findings that can't be fixed are explained in `docs/security-review/false-positives.md`; keep it current when the code changes.

Because it's managed, any hard-coded object or field name in a JS or dynamic-SOQL string needs the `massapprv__` prefix to work in customer orgs. Static Apex references get the prefix automatically. Components in a promoted managed version are very hard to remove, so don't add metadata to `force-app` unless it belongs in the product.

## Commands

Apex (needs the Salesforce CLI and an authorized org):

```bash
sf project deploy start --source-dir force-app            # deploy
sf apex run test --test-level RunLocalTests --code-coverage --result-format human --wait 10
sf apex run test --class-names RSOCL_MultipleApprovalControllerTest --result-format human --wait 10   # one test class
sf apex run test --tests RSOCL_MultipleApprovalControllerTest.testProcessRecords --wait 10            # one test method
```

JS tooling (`npm install` first):

```bash
npm run lint              # ESLint over aura/lwc JS
npm run test:unit         # LWC Jest (sfdx-lwc-jest); no __tests__ exist yet
npx sfdx-lwc-jest -- path/to/__tests__/foo.test.js   # single Jest file
npm run prettier          # format (Apex, XML, LWC html, etc.)
npm run prettier:verify
```

A Husky pre-commit hook runs `lint-staged`: Prettier on staged files, ESLint on aura/lwc JS, and related Jest tests for staged LWC files.

The current branch work is about fixing PMD (Apex static analysis) warnings. Silence a rule you have deliberately accepted with a class- or method-level `@SuppressWarnings('PMD.RuleName')`, the way the existing code does.

## Repository layout gotcha

`force-app/` is the single source of truth for the package. The untracked `Bulk Records Approval App/` folder is an older full copy of the project kept only as a backup: don't edit it or build packages from it. Its extra metadata (`Purchase_Orders__c`, standard-app utility bars, `sfdc_default_ReportExport_Protection_Flow`, `Object_Approval_Data_Settings__c`, the `Pending_Approval_Records` tab) was left out of the package on purpose.

## Architecture

**Apex** (all classes prefixed `RSOCL_`, `with sharing`, under `force-app/main/default/classes`):

- `RSOCL_MockDaoProcessInstanceController` is the real data-access layer, despite its name. It defines the inner interface `IProcessDefination` and implements it with every SOQL against `ProcessInstance` / `ProcessDefinition` / `Approval_Data_Setting__c`, plus `getSObjectMap` for dynamic queries (`Database.queryWithBinds`, SYSTEM_MODE).
- Each controller has a `@TestVisible public static IProcessDefination processListInstance` field set to that DAO. Tests swap in `RSOCL_MockProcessInstanceControllerTest`, a test-only mock that implements the same interface over in-memory lists (`processInstanceList`, `approvalDataSettingList`, `sObjectMap`) and has `getFakeId(SObjectType)`. Approval records can't be created in tests, so tests build `ProcessInstance` objects by deserializing JSON. Any new query a controller needs must be added to the interface, the DAO **and** the mock.
- The controllers (one per LWC) all follow the same pipeline:
  1. Fetch process instances through the DAO.
  2. Group target record Ids by object (`buildObjectIdMap`).
  3. Read the configured display fields per object from `Approval_Data_Setting__c` (`Object_API_name__c` and a comma-separated `Approval_Fields__c`, which may include one-level relationship fields such as `Account.Name`).
  4. Run one dynamic query per object (guarded against the 100-SOQL limit).
  5. Map everything into `@AuraEnabled` wrapper classes.

  The controllers are:
  - `RSOCL_MultipleApprovalController`: the current user's pending items, plus `processRecords`, which bulk approves or rejects through `Approval.ProcessWorkitemRequest` (it takes a JSON string of `{workItemId, comment}`).
  - `RSOCL_ApprovalProcessedDataController`: items the user approved or rejected in the last 7 days.
  - `RSOCL_AdminViewController`: pending items across all users.
  - `RSOCL_ApprovalDataSettingController`: lists the objects that have active approval processes and their fields, and saves `Approval_Data_Setting__c`.

- `RSOCL_SchemaUtil` checks object and field names (including one-level `Rel.Field` paths) against the org schema. Every name stored in `Approval_Fields__c` or used in the dynamic queries must go through it; this is the package's protection against SOQL injection.
- `RSOCL_ExceptionLogger.logError(e, className, methodName)` inserts an `Exception_Logger__c` record. Every `@AuraEnabled` method catches its exception, logs it this way, and throws `RSOCL_ExceptionLogger.userFacingException()`, which carries only a generic message.
- `RSOCL_MockProcessInstanceControllerTest` is `@IsTest` and holds the shared test helpers (`getFakeId`, `assignPackagePermissionSet`). Tests that hit `USER_MODE` code must assign the package permission set first, because the package build runs tests as a user without it.
- `RSOCL_MultipleApprovalController.getObjectName` returns `'Opportunity'` while `Test.isRunningTest()` is true, because the tests use hard-coded fake Opportunity Ids.

**LWC** (`force-app/main/default/lwc`), each component exposed as a Tab or App page:

| Component                   | What it shows                         | Apex it calls                                                  |
| --------------------------- | ------------------------------------- | -------------------------------------------------------------- |
| `massApprovalComponent`     | Main approver UI                      | `RSOCL_MultipleApprovalController`                             |
| `recentlyApprovedComp`      | Requests processed in the last 7 days | `RSOCL_ApprovalProcessedDataController`                        |
| `adminViewComponent`        | Admin view across all users           | `RSOCL_AdminViewController`                                    |
| `approvalDataSettingComp`   | Field configuration                   | `RSOCL_ApprovalDataSettingController`                          |
| `setupInstructionComponent` | Setup wizard                          | Embeds `assignPermissionSetComp` and `approvalDataSettingComp` |

`massApprovalComponent` and `setupInstructionComponent` load the `Bootstrap5` static resource.

**Aura**: `ParentApprovalDataSettingComp` and `ParentAssignPermissionSetComp` are thin wrappers that let the LWCs be used where only Aura is supported (`lightning:isUrlAddressable`, quick actions, etc.).
