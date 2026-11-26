# Mass Records Approval – Reviewer Test Org Setup

The Salesforce security reviewer needs a long-lived org with the **final released version** installed, working sample
data and two logins. Use a **Developer Edition** org; scratch orgs expire after 30 days or less.

A Developer Edition org includes two full Salesforce user licenses, which is exactly what this setup needs:

| User                         | Profile              | Permission set                               | Role in the test                                                      |
| ---------------------------- | -------------------- | -------------------------------------------- | --------------------------------------------------------------------- |
| Admin (the org's first user) | System Administrator | Admin Access to Mass Approval Product        | Sets up the app, owns and submits the sample records, uses Admin View |
| Approver (second user)       | Standard User        | General User Access to Mass Product **only** | Receives the sample requests, approves and rejects them               |

## 1. Create the org

1. Sign up at https://developer.salesforce.com/signup with an email address your team monitors.
2. Log in, then set a password and security question.

## 2. Install the final version

1. Open `https://login.salesforce.com/packaging/installPackage.apexp?p0=<final 04t>` in that org.
2. Choose **Install for Admins Only** and install. Check **Setup → Installed Packages**.

## 3. Create the approver user

1. **Setup → Users → New User**.
2. Fill in: First/Last name, Email, Username (globally unique, for example `approver.mra-review@<your domain>`),
   **User License: Salesforce**, **Profile: Standard User**.
3. Save. Set the password from the activation email (or **Reset Password**).

## 4. Assign the permission sets

- Admin user: **Admin Access to Mass Approval Product**.
- Approver user: **General User Access to Mass Product** only.

(Setup → Permission Sets → _permission set_ → Manage Assignments → Add Assignment.)

## 5. Create the approval process

1. **Setup → Process Automation → Approval Processes**, choose **Opportunity**, **Create New Approval Process →
   Use Jump Start Wizard**.
2. Name: `MRA Review Approval`. Entry criteria: **No criteria** (all records).
3. Approver: **Automatically assign to approver(s)** → User → the approver user from step 3.
4. Save, then **Activate**.
5. Add **Submit for Approval** and **Approval History** to the Opportunity page layout (see the installation guide,
   section 5).

## 6. Configure the displayed fields

As the admin user: **Let's Approve Admin → Setup → Continue → Next → Next → New**. Choose **Opportunity**, select
**Amount**, **Stage** and **Account ID**, and click **Save**.

(The script in step 7 can create this setting instead; skip it there if you did it here.)

## 7. Create sample pending requests

As the admin user: **Developer Console → Debug → Open Execute Anonymous Window**, paste and run:

```apex
// Sample data for the security review: 5 Opportunities submitted for approval to the approver user.
// Run as the admin user, who owns the records and is allowed to submit them.
if ([SELECT COUNT() FROM massapprv__Approval_Data_Setting__c WHERE massapprv__Object_API_name__c = 'Opportunity'] == 0) {
    insert new massapprv__Approval_Data_Setting__c(
        massapprv__Object_API_name__c = 'Opportunity',
        massapprv__Approval_Fields__c = 'Amount,StageName,Account.Name'
    );
}

Account acc = new Account(Name = 'Review Demo Account');
insert acc;

List<Opportunity> opps = new List<Opportunity>();
for (Integer i = 1; i <= 5; i++) {
    opps.add(new Opportunity(
        Name = 'Review Demo Opportunity ' + i,
        AccountId = acc.Id,
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(30),
        Amount = 1000 * i
    ));
}
insert opps;

List<Approval.ProcessSubmitRequest> requests = new List<Approval.ProcessSubmitRequest>();
for (Opportunity o : opps) {
    Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
    req.setObjectId(o.Id);
    req.setComments('Sample request for the security review');
    requests.add(req);
}
for (Approval.ProcessResult r : Approval.process(requests)) {
    System.debug('Submitted ' + r.getEntityId() + ': ' + r.getInstanceStatus());
}
```

Expected: 5 lines `Submitted …: Pending` in the log.

## 8. Verify before submitting

1. Log in as the **approver**: **Let's Approve → Approval Request** shows 5 Opportunity requests with Amount, Stage and
   Account name.
2. Approve one and reject one. Both appear under **Recently Approved/Rejected**. Leave the other 3 pending for the reviewer.
3. Log in as the **admin**: **Admin View** lists the pending requests.

If the approver gets an "access" error on any tab, check that the General User permission set is assigned and the
installed version is the final one.

## 9. Logins for the submission

Enter these in the Partner Console's security review form. **Do not commit real passwords to Git**; keep this table
filled in only in a private copy.

| Role     | Username | Password | Profile              | Permission set                        | Notes |
| -------- | -------- | -------- | -------------------- | ------------------------------------- | ----- |
| Admin    |          |          | System Administrator | Admin Access to Mass Approval Product |       |
| Approver |          |          | Standard User        | General User Access to Mass Product   |       |

Org ID: ____________ · Installed version: 1.1.0.____ (`04t____________`) · Prepared on: ____________
