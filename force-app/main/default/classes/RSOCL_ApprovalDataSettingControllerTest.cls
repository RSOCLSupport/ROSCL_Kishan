@isTest
public with sharing class RSOCL_ApprovalDataSettingControllerTest{
    @isTest
    public static void testGetObjects(){
        try{
        Test.startTest();
        List<RSOCL_ApprovalDataSettingController.ObjectWrap> objWrapList;
        RSOCL_MockProcessInstanceControllerTest mockDaoTest = new RSOCL_MockProcessInstanceControllerTest();
        RSOCL_MockDaoProcessInstanceController mockDao = new RSOCL_MockDaoProcessInstanceController();

        mockDao.getObjects('Inactive', 'Type');

        string processDefinationData = '{"Name":"Test Approval", "State":"Inactive", "Type":"Approval", "TableEnumOrId":"Contact"}';
        ProcessDefinition pd = (ProcessDefinition)JSON.deserialize(processDefinationData, ProcessDefinition.class);
        mockDaoTest.processDefination.add(pd);

        RSOCL_ApprovalDataSettingController.processListInstance = mockDaoTest;
        objWrapList = RSOCL_ApprovalDataSettingController.getObjects();
        Test.stopTest();

        System.assertEquals(1, objWrapList.size(), 'Process definition records should be present.');
        }
        catch(Exception e){
            RSOCL_ExceptionLogger.logError(e, 'RSOCL_ApprovalDataSettingControllerTest', 'testGetObjects');
        }
    }

    @isTest
    public static void testSaveApproveSettings(){
        try{
        Test.startTest();
        RSOCL_ApprovalDataSettingController.SaveResult saveResult = new RSOCL_ApprovalDataSettingController.SaveResult();
        RSOCL_MockProcessInstanceControllerTest mockDaoTest = new RSOCL_MockProcessInstanceControllerTest();
        RSOCL_MockDaoProcessInstanceController mockDao = new RSOCL_MockDaoProcessInstanceController();

        mockDao.getApprovalDataSettings('Opportunity');

        Approval_Data_Setting__c approvalData = new Approval_Data_Setting__c();

        RSOCL_ApprovalDataSettingController.processListInstance = mockDaoTest;
        saveResult = RSOCL_ApprovalDataSettingController.saveApproveSettings('Opportunity', new List<String>{ 'OwnerId' });
        Test.stopTest();

        System.assertEquals(saveResult.status, 'SUCCESS', 'Approval data settings result is not success');
    }
    catch(Exception e){
        RSOCL_ExceptionLogger.logError(e, 'RSOCL_ApprovalDataSettingControllerTest', 'testSaveApproveSettings');
    }
    }

    @isTest
    public static void testGetFields(){
        try{
        Test.startTest();
        List<RSOCL_ApprovalDataSettingController.FieldWrap> fieldWrapList = new List<RSOCL_ApprovalDataSettingController.FieldWrap>();
        fieldWrapList = RSOCL_ApprovalDataSettingController.getFields('Opportunity');
        Test.stopTest();

        System.assert(fieldWrapList.size() > 0, 'field wrapper list size is should not be zero');
    }
    catch(Exception e){
        RSOCL_ExceptionLogger.logError(e, 'RSOCL_ApprovalDataSettingControllerTest', 'testGetFields');
    }
    }

}