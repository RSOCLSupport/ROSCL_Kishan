# Mass Records Approval – Manual UI Test Checklist (T6–T11)

Run these in a scratch or Developer Edition org with the final version installed, an active approval process and sample
pending requests (see `reviewer-org-setup.md`). Record Pass/Fail and notes for each step.

Expected results describe the **current** behavior. Items marked _Known_ are existing issues that were deliberately not
changed in this version; they are not failures.

Tester: ____________ · Org: ____________ · Version: 1.1.0.____ · Date: ____________

## T6 – Admin screens (Admin permission set)

| #   | Step                                                                  | Expected                                                                                                             | Pass/Fail | Notes                                                                                         |
| --- | --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | --------- | --------------------------------------------------------------------------------------------- |
| 6.1 | App Launcher → **Let's Approve Admin**                                | Tabs: Setup, Approval Request, Recently Approved/Rejected, Admin View, Approval Data Settings                        |           |                                                                                               |
| 6.2 | **Setup** → **Continue**                                              | Step One: permission set instructions for general users                                                              |           |                                                                                               |
| 6.3 | **Next**                                                              | Step Two: instructions for admin users                                                                               |           |                                                                                               |
| 6.4 | **Next** → **New**                                                    | _Create Approval Data Settings Record_ window; **Select Objects** lists only objects with an active approval process |           |                                                                                               |
| 6.5 | Choose an object that already has a setting, select a field, **Save** | The existing setting is reported; no duplicate is created                                                            |           |                                                                                               |
| 6.6 | Choose an object without a setting, select fields, **Save**           | Success message with the new record's name                                                                           |           |                                                                                               |
| 6.7 | **Admin View**                                                        | Pending requests grouped by object, with configured fields                                                           |           | _Known:_ only requests changed in the last 7 days are shown; the **Approver** column is blank |
| 6.8 | **Approval Data Settings** tab                                        | Setting records are listed and can be opened                                                                         |           |                                                                                               |

## T7 – Bulk approve and reject (approver)

| #    | Step                                                                 | Expected                                                                                                    | Pass/Fail | Notes                                                                    |
| ---- | -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | --------- | ------------------------------------------------------------------------ |
| 7.1  | **Approval Request** → **+** on the object row                       | Requests listed with submitter, date, message and configured fields; values shown without quotes            |           |                                                                          |
| 7.2  | Click a record name                                                  | _Record Detail_ pop-up; **View Full Record Information** opens the record in a new tab; **Close** closes it |           |                                                                          |
| 7.3  | **Add Comment** on one request, type text, **Save**                  | Comment shown in the Comment column                                                                         |           |                                                                          |
| 7.4  | **Add Comment**, tick _add same comment for all … records_, **Save** | Same comment on every request of that object                                                                |           |                                                                          |
| 7.5  | Tick 2 requests                                                      | Object row shows _2 out of N selected_                                                                      |           |                                                                          |
| 7.6  | **Approve**                                                          | _All records are Approved successfully_; list reloads without them                                          |           | _Known:_ the Approve button stays greyed out until the page is refreshed |
| 7.7  | Refresh, tick 1 request, **Reject**                                  | _All records are Rejected successfully_; list reloads                                                       |           | _Known:_ the Reject button stays greyed out until refresh                |
| 7.8  | **Approve** with nothing ticked                                      | Error message _Please select items to Apporve._                                                             |           | _Known:_ spelling as shown                                               |
| 7.9  | **Recently Approved/Rejected**                                       | _Last Week Approved_ (green) and _Last Week Rejected_ (red) groups with the requests and comments           |           |                                                                          |
| 7.10 | Open the record → Approval History                                   | Decision and comment recorded                                                                               |           |                                                                          |

## T8 – Queue and delegated approver

Setup: create a queue for the object containing the approver user; create a second approval process (or step) that
assigns to that queue. On another user's record, set **Delegated Approver** = the approver user, and submit a record to
that other user.

| #   | Step                                | Expected                                                                                          | Pass/Fail | Notes |
| --- | ----------------------------------- | ------------------------------------------------------------------------------------------------- | --------- | ----- |
| 8.1 | Approver opens **Approval Request** | Request assigned to the queue is listed                                                           |           |       |
| 8.2 | Same screen                         | Request assigned to the delegating user is listed, name shown in **orange**; own requests in blue |           |       |
| 8.3 | Approve both                        | Both succeed and move to Recently Approved/Rejected                                               |           |       |

## T9 – Multi-step approval process

Setup: an approval process with two steps, step 1 approver = user A, step 2 approver = user B (both with the General
User permission set). Submit a record.

| #   | Step                                     | Expected                                        | Pass/Fail | Notes                                                                      |
| --- | ---------------------------------------- | ----------------------------------------------- | --------- | -------------------------------------------------------------------------- |
| 9.1 | User A → Approval Request                | Request listed                                  |           |                                                                            |
| 9.2 | User A approves                          | Success; request leaves A's list                |           |                                                                            |
| 9.3 | User B → Approval Request                | **Record whether the step-2 request is listed** |           | Not yet verified; the pending query filters on requests with no last actor |
| 9.4 | Standard **Items to Approve** for user B | Step-2 request present (control check)          |           |                                                                            |

## T10 – Multiple objects

Setup: approval processes on two objects (for example Opportunity and a custom object), a field setting for each, and
pending requests on both.

| #    | Step                                         | Expected                                    | Pass/Fail | Notes |
| ---- | -------------------------------------------- | ------------------------------------------- | --------- | ----- |
| 10.1 | **Approval Request**                         | One row per object, each with its own count |           |       |
| 10.2 | Expand both                                  | Each shows its own configured fields        |           |       |
| 10.3 | Tick requests from both objects, **Approve** | All succeed in one action                   |           |       |

## T11 – Mobile

| #    | Step                                                                                           | Expected                          | Pass/Fail | Notes |
| ---- | ---------------------------------------------------------------------------------------------- | --------------------------------- | --------- | ----- |
| 11.1 | Salesforce mobile app → **Let's Approve Admin Mobile** (admin) or **Let's Approve** (approver) | App opens; tabs listed            |           |       |
| 11.2 | **Approval Request**                                                                           | Mobile layout of the request list |           |       |
| 11.3 | Tick a request, **Approve**                                                                    | Success message; list reloads     |           |       |
| 11.4 | **Recently Approved/Rejected**                                                                 | Groups and requests shown         |           |       |

## Result

| Test | Result | Tester | Date |
| ---- | ------ | ------ | ---- |
| T6   |        |        |      |
| T7   |        |        |      |
| T8   |        |        |      |
| T9   |        |        |      |
| T10  |        |        |      |
| T11  |        |        |      |
