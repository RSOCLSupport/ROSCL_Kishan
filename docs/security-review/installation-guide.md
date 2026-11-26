# Mass Records Approval (Let's Approve) – Installation and Configuration Guide

Package: Mass Records Approval, managed package, namespace `massapprv`, version 1.1.0.2 (`04tdM000000fghdQAA`).

## 1. Install the package

| Org type                        | Install link                                                                        |
| ------------------------------- | ----------------------------------------------------------------------------------- |
| Production or Developer Edition | `https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdM000000fghdQAA` |
| Sandbox                         | `https://test.salesforce.com/packaging/installPackage.apexp?p0=04tdM000000fghdQAA`  |

1. Open the link while logged in as a System Administrator.
2. Choose **Install for Admins Only** (recommended; access is then granted with the permission sets below), and click **Install**.
3. Wait for the confirmation email, then check **Setup → Installed Packages**: _Mass Records Approval_ is listed with namespace `massapprv`.

CLI alternative:

```bash
sf package install -p 04tdM000000fghdQAA -o <org alias> -s AdminsOnly -w 30
```

## 2. Assign the permission sets

The package contains two permission sets. Every user of the app needs one of them.

| Permission set                            | Give it to                                    | Grants                                                                                                                                                                                             |
| ----------------------------------------- | --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **General User Access to Mass Product**   | Every approver                                | App _Let's Approve_; tabs Approval Request and Recently Approved/Rejected; access to the two approver controllers; read access to Approval Data Settings; create access to the error log           |
| **Admin Access to Mass Approval Product** | Administrators who set up and monitor the app | Apps _Let's Approve Admin_ and _Let's Approve Admin Mobile_; all five tabs including Setup and Admin View; access to all four controllers; full access to Approval Data Settings and the error log |

Steps: **Setup → Users → Permission Sets** → open the permission set → **Manage Assignments** → **Add Assignment** → select users → **Assign**.

CLI alternative:

```bash
sf org assign permset -n massapprv__General_User_Access_to_Mass_Product -o <org alias> -b <username>
sf org assign permset -n massapprv__Admin_Access_to_Mass_Approval_Product -o <org alias> -b <username>
```

The app's **Setup** tab (Let's Approve Admin → Setup → Continue) shows these steps on screen as Step One and Step Two.

## 3. Create an approval process

The app shows requests from standard Salesforce approval processes; it does not create them. Every object whose requests
should appear needs an **active** approval process.

1. **Setup → Process Automation → Approval Processes**.
2. In _Manage Approval Processes For_, choose the object (for example Opportunity).
3. **Create New Approval Process → Use Jump Start Wizard** (or the Standard Setup Wizard).
4. Enter a name, set the entry criteria, and choose the approver: a named user, the submitter's manager, a queue,
   or a related user field.
5. **Save**, then click **Activate**.

Requests assigned to a queue appear for every queue member. Requests assigned to a user who has named a
**Delegated Approver** (on their User record) also appear for that delegate.

## 4. Configure which fields approvers see

1. Open **Let's Approve Admin → Setup → Continue**, then click **Next** twice to reach Step Three, or open the
   **Approval Data Settings** tab.
2. Click **New**.
3. In **Select Objects**, choose the object. Only objects with an active approval process are listed.
4. Move the fields to show from **Available Options** to **Selected Options**. Fields from a related record (one level,
   for example the Account name on an Opportunity) can be included.
5. Click **Save**. There is one setting per object; to change it later, edit its record on the
   **Approval Data Settings** tab.

The value of a field an approver is not allowed to read is never shown to that approver; the field's label appears with
"No Data Present" instead.

## 5. Add Submit for Approval and Approval History to page layouts

Salesforce does not add these automatically when an approval process is created. Without them, users can't submit
records from the record page or see a record's approval history.

1. **Setup → Object Manager →** _object_ **→ Page Layouts**, and open each layout used.
2. **Submit for Approval:** in the palette, choose **Mobile & Lightning Actions**, drag **Submit for Approval** into
   _Salesforce Mobile and Lightning Experience Actions_ (click _override the predefined actions_ first if the section
   is not editable).
3. **Approval History:** in the palette, choose **Related Lists**, drag **Approval History** onto the layout.
4. **Save**. Repeat for every object with an approval process.

Records can also be submitted for approval by a Flow (Submit for Approval action) or by Apex, without a button.

## 6. Check the installation

1. Log in as an approver and open **Let's Approve → Approval Request**.
2. Submit a record for approval to that approver: it appears, grouped under its object, with the configured fields.
3. Approve or reject it: a success message appears, and the record moves to **Recently Approved/Rejected**.

Errors, if any, are recorded in the **Exception Logger** object (class, method, line, error type and message) for
administrators.
