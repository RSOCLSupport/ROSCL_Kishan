@IsTest
@SuppressWarnings('PMD.AvoidHardcodingId')
public with sharing class RSOCL_AdminViewControllerTest {

    @TestSetup
    static void setupTestData(){
        assignPackagePermissionSet(UserInfo.getUserId());
    }

    private static User getRunningUser(){
        return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    }

    @IsTest
    public static void testGetSubmittedApprovalRecordsByAllUsers(){
        System.runAs(getRunningUser()){
            RSOCL_MockProcessInstanceControllerTest mockDaoTest = new RSOCL_MockProcessInstanceControllerTest();
            RSOCL_MockDaoProcessInstanceController mockDao = new RSOCL_MockDaoProcessInstanceController();
            mockDao.getProcessInstance(null, null);
            mockDao.getApprovalDataSettings();

            String oppId = RSOCL_MockProcessInstanceControllerTest.getFakeId(Opportunity.SObjectType);
            String processInstanceData = '{"Id":"04g2w000003rbSHAAZ","TargetObjectId":"' + oppId + '","CreatedDate":"2023-03-11T09:20:50.000Z", ' + 
                                     '"Workitems": {"totalSize": "1","done": true, "records":[{"ProcessInstanceId":"04g2w000003rbSHAAZ","Id":"04i2w000004P4BYAA0","OriginalActorId":"0052w00000DyipuAAB"}]},' + 
                                     '"Steps":{"totalSize": "1","done": true, "records":[{"ProcessInstanceId":"04g2w000003rbSHAAY","Id":"04h2w000005Nd8ZAAS","OriginalActorId":"0052w00000DyipuAAA","Comments":"asdasd", "StepStatus":"Approved", "SystemModstamp":"2023-03-11T09:20:50.000Z"}]}}';

            ProcessInstance processInstance = (ProcessInstance)JSON.deserialize(processInstanceData, ProcessInstance.class);
            Map<Id, sObject> sObjectMap = new Map<Id, sObject>();
            Opportunity opp = new Opportunity(Id = oppId);
            sObjectMap.put(oppId, opp);

            Approval_Data_Setting__c testApprovalData = new Approval_Data_Setting__c(
                Id = RSOCL_MockProcessInstanceControllerTest.getFakeId(Approval_Data_Setting__c.SObjectType), 
                Approval_Fields__c = 'AccountId', 
                Object_API_name__c = 'Opportunity'
            );

            mockDaoTest.processInstanceList.add(processInstance);
            mockDaoTest.approvalDataSettingList.add(testApprovalData);
            mockDaoTest.sObjectMap = sObjectMap;

            RSOCL_AdminViewController.processListInstance = mockDaoTest;
            
            Test.startTest();
            List<RSOCL_AdminViewController.SubmittedRecordsWrapper> result = RSOCL_AdminViewController.getSubmittedApprovalRecordsByAllUsers();
            Test.stopTest();

            Assert.areEqual(1, result.size(), 'Result size should be 1');
            Assert.areEqual(oppId, result[0].recordId, 'Record ID should match');
        }
    }

    @IsTest
    public static void testGetSubmittedApprovalRecordsMultipleAndCrossObject(){
        System.runAs(getRunningUser()){
            RSOCL_MockProcessInstanceControllerTest mockDaoTest = new RSOCL_MockProcessInstanceControllerTest();

            String oppId1 = RSOCL_MockProcessInstanceControllerTest.getFakeId(Opportunity.SObjectType);
            String oppId2 = RSOCL_MockProcessInstanceControllerTest.getFakeId(Opportunity.SObjectType);
            String accId = RSOCL_MockProcessInstanceControllerTest.getFakeId(Account.SObjectType);

            String piData1 = '{"Id":"04g2w000003rbSHAA1","TargetObjectId":"' + oppId1 + '","CreatedDate":"2023-03-11T09:20:50.000Z", ' + 
                             '"Workitems": {"totalSize": "1","done": true, "records":[{"ProcessInstanceId":"04g2w000003rbSHAA1","Id":"04i2w000004P4BYAA1","OriginalActorId":"0052w00000DyipuAA1"}]},' + 
                             '"Steps":{"totalSize": "1","done": true, "records":[{"ProcessInstanceId":"04g2w000003rbSHAAY","Id":"04h2w000005Nd8ZAA1","OriginalActorId":"0052w00000DyipuAA1","Comments":"test comment", "StepStatus":"Approved", "SystemModstamp":"2023-03-11T09:20:50.000Z"}]}}';

            String piData2 = '{"Id":"04g2w000003rbSHAA2","TargetObjectId":"' + oppId2 + '","CreatedDate":"2023-03-11T09:20:50.000Z", ' + 
                             '"Workitems": {"totalSize": "1","done": true, "records":[{"ProcessInstanceId":"04g2w000003rbSHAA2","Id":"04i2w000004P4BYAA2","OriginalActorId":"0052w00000DyipuAA2"}]},' + 
                             '"Steps":{"totalSize": "1","done": true, "records":[{"ProcessInstanceId":"04g2w000003rbSHAAY","Id":"04h2w000005Nd8ZAA2","OriginalActorId":"0052w00000DyipuAA2","Comments":"test comment 2", "StepStatus":"Approved", "SystemModstamp":"2023-03-11T09:20:50.000Z"}]}}';

            ProcessInstance pi1 = (ProcessInstance)JSON.deserialize(piData1, ProcessInstance.class);
            ProcessInstance pi2 = (ProcessInstance)JSON.deserialize(piData2, ProcessInstance.class);

            String oppJson1 = '{"attributes":{"type":"Opportunity"},"Id":"' + oppId1 + '","AccountId":"' + accId + '","Account":{"attributes":{"type":"Account"},"Name":"Test Account"}}';
            Opportunity opp1 = (Opportunity)JSON.deserialize(oppJson1, Opportunity.class);
            Opportunity opp2 = new Opportunity(Id = oppId2);

            Map<Id, sObject> sObjectMap = new Map<Id, sObject>();
            sObjectMap.put(oppId1, opp1);
            sObjectMap.put(oppId2, opp2);

            Approval_Data_Setting__c setting = new Approval_Data_Setting__c(
                Id = RSOCL_MockProcessInstanceControllerTest.getFakeId(Approval_Data_Setting__c.SObjectType), 
                Approval_Fields__c = 'AccountId,Account.Name', 
                Object_API_name__c = 'Opportunity'
            );

            mockDaoTest.processInstanceList.add(pi1);
            mockDaoTest.processInstanceList.add(pi2);
            mockDaoTest.approvalDataSettingList.add(setting);
            mockDaoTest.sObjectMap = sObjectMap;

            RSOCL_AdminViewController.processListInstance = mockDaoTest;

            Test.startTest();
            List<RSOCL_AdminViewController.SubmittedRecordsWrapper> result = RSOCL_AdminViewController.getSubmittedApprovalRecordsByAllUsers();
            Test.stopTest();

            Assert.areEqual(2, result.size(), 'Should return 2 records');
        }
    }

    @IsTest
    public static void testGetSubmittedApprovalRecordsEmpty(){
        System.runAs(getRunningUser()){
            RSOCL_MockProcessInstanceControllerTest mockDaoTest = new RSOCL_MockProcessInstanceControllerTest();
            RSOCL_AdminViewController.processListInstance = mockDaoTest;

            Test.startTest();
            List<RSOCL_AdminViewController.SubmittedRecordsWrapper> result = RSOCL_AdminViewController.getSubmittedApprovalRecordsByAllUsers();
            Test.stopTest();

            Assert.isTrue(result.isEmpty(), 'Result should be empty when no process instances exist');
        }
    }

    @IsTest
    public static void testGetSubmittedApprovalRecordsException(){
        System.runAs(getRunningUser()){
            RSOCL_AdminViewController.processListInstance = null;
            Boolean isExceptionThrown = false;

            Test.startTest();
            try{
                RSOCL_AdminViewController.getSubmittedApprovalRecordsByAllUsers();
            }catch(AuraHandledException e){
                isExceptionThrown = true;
            }
            Test.stopTest();

            Assert.isTrue(isExceptionThrown, 'AuraHandledException should be thrown when processListInstance is null');
        }
    }

    private static void assignPackagePermissionSet(Id userId){
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Admin_Access_to_Mass_Approval_Product' LIMIT 1];
        List<PermissionSetAssignment> existingAssignments = [
            SELECT Id FROM PermissionSetAssignment 
            WHERE AssigneeId = :userId AND PermissionSetId = :ps.Id
        ];
        if(existingAssignments.isEmpty()){
            insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id);
        }
    }
}
