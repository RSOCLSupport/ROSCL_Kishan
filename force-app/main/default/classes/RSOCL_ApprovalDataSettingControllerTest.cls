@IsTest
private class RSOCL_ApprovalDataSettingControllerTest {

    private static User getRunningUser(){
        return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    }

    @IsTest
    static void testGetObjects(){
        System.runAs(getRunningUser()){
            RSOCL_MockProcessInstanceControllerTest mockDaoTest = new RSOCL_MockProcessInstanceControllerTest();
            RSOCL_MockDaoProcessInstanceController mockDao = new RSOCL_MockDaoProcessInstanceController();

            Test.startTest();
            mockDao.getObjects('Inactive', 'Type');

            String processDefinationData = '{"Name":"Test Approval", "State":"Inactive", "Type":"Approval", "TableEnumOrId":"Contact"}';
            ProcessDefinition pd = (ProcessDefinition)JSON.deserialize(processDefinationData, ProcessDefinition.class);
            mockDaoTest.processDefination.add(pd);

            RSOCL_ApprovalDataSettingController.processListInstance = mockDaoTest;
            List<RSOCL_ApprovalDataSettingController.ObjectWrap> objWrapList = RSOCL_ApprovalDataSettingController.getObjects();
            Test.stopTest();

            Assert.areEqual(1, objWrapList.size(), 'Process definition records should be present.');
        }
    }

    @IsTest
    static void testGetObjectsWhenNoProcess(){
        System.runAs(getRunningUser()){
            RSOCL_ApprovalDataSettingController.processListInstance = new RSOCL_MockProcessInstanceControllerTest();

            Test.startTest();
            List<RSOCL_ApprovalDataSettingController.ObjectWrap> objWrapList = RSOCL_ApprovalDataSettingController.getObjects();
            Test.stopTest();

            Assert.isTrue(objWrapList.isEmpty(), 'List should be empty when there is no active approval process.');
        }
    }

    @IsTest
    static void testSaveApproveSettings(){
        System.runAs(getRunningUser()){
            RSOCL_MockProcessInstanceControllerTest mockDaoTest = new RSOCL_MockProcessInstanceControllerTest();
            RSOCL_MockDaoProcessInstanceController mockDao = new RSOCL_MockDaoProcessInstanceController();

            Test.startTest();
            mockDao.getApprovalDataSettings('Opportunity');

            RSOCL_ApprovalDataSettingController.processListInstance = mockDaoTest;
            RSOCL_ApprovalDataSettingController.SaveResult saveResult = RSOCL_ApprovalDataSettingController.saveApproveSettings('Opportunity', new List<String>{ 'OwnerId' });
            Test.stopTest();

            Assert.areEqual('SUCCESS', saveResult.status, 'Approval data settings result is not success');
        }
    }

    @IsTest
    static void testSaveApproveSettingsExistingRecord(){
        System.runAs(getRunningUser()){
            Approval_Data_Setting__c existing = new Approval_Data_Setting__c();
            existing.Object_API_name__c = 'Opportunity';
            existing.Approval_Fields__c = 'OwnerId,';
            insert existing;

            Test.startTest();
            RSOCL_ApprovalDataSettingController.SaveResult saveResult = RSOCL_ApprovalDataSettingController.saveApproveSettings('Opportunity', new List<String>{ 'OwnerId' });
            Test.stopTest();

            Assert.areEqual('Existing Record', saveResult.status, 'Existing setting should be returned.');
            Assert.areEqual(existing.Id, saveResult.recordId, 'Existing record id should match.');
        }
    }

    @IsTest
    static void testSaveApproveSettingsException(){
        System.runAs(getRunningUser()){
            RSOCL_ApprovalDataSettingController.processListInstance = new RSOCL_MockProcessInstanceControllerTest();
            Boolean isExceptionThrown = false;

            Test.startTest();
            try{
                RSOCL_ApprovalDataSettingController.saveApproveSettings('Opportunity', null);
            }catch(AuraHandledException e){
                isExceptionThrown = true;
            }
            Test.stopTest();

            Assert.isTrue(isExceptionThrown, 'AuraHandledException should be thrown for null field list.');
        }
    }

    @IsTest
    static void testGetFields(){
        System.runAs(getRunningUser()){
            Test.startTest();
            List<RSOCL_ApprovalDataSettingController.FieldWrap> fieldWrapList = RSOCL_ApprovalDataSettingController.getFields('Opportunity');
            Test.stopTest();

            Assert.isFalse(fieldWrapList.isEmpty(), 'field wrapper list size should not be zero');
        }
    }

    @IsTest
    static void testGetFieldsException(){
        System.runAs(getRunningUser()){
            Boolean isExceptionThrown = false;

            Test.startTest();
            try{
                RSOCL_ApprovalDataSettingController.getFields('Invalid_Object__c');
            }catch(AuraHandledException e){
                isExceptionThrown = true;
            }
            Test.stopTest();

            Assert.isTrue(isExceptionThrown, 'AuraHandledException should be thrown for invalid object.');
        }
    }
}