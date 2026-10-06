@isTest
public with sharing class RSOCL_MultipleApprovalControllerTest{
    @isTest
    public static void testGetSubmittedApprovalRecords(){
        try{
            RSOCL_MockProcessInstanceControllerTest mockDaoTest = new RSOCL_MockProcessInstanceControllerTest();
            RSOCL_MockDaoProcessInstanceController mockDao = new RSOCL_MockDaoProcessInstanceController();
            mockDao.getProcessInstance(null, null, null, null, null);

            String processInstanceData = '{"Id":"04g2w000003rbSHAAZ","TargetObjectId":"0062w00000KdcZCAAZ","CreatedDate":"2023-03-11T09:20:50.000Z", ' + 
                                     '"Workitems": {"totalSize": "1","done": true, "records":[{"ProcessInstanceId":"04g2w000003rbSHAAZ","Id":"04i2w000004P4BYAA0","OriginalActorId":"0052w00000DyipuAAB"}]},' + 
                                     '"Steps":{"totalSize": "1","done": true, "records":[{"ProcessInstanceId":"04g2w000003rbSHAAY","Id":"04h2w000005Nd8ZAAS","OriginalActorId":"0052w00000DyipuAAA"}]}}';

            ProcessInstance processInstance = (ProcessInstance)JSON.deserialize(processInstanceData, ProcessInstance.class);
            Approval_Data_Setting__c testApprovalData = new Approval_Data_Setting__c(Id = RSOCL_MockProcessInstanceControllerTest.getFakeId(Approval_Data_Setting__c.SObjectType), Approval_Fields__c = 'AccountId', Object_API_name__c = 'Opportunity');

            mockDaoTest.processInstanceList.add(processInstance);
            mockDaoTest.approvalDataSettingList.add(testApprovalData);
            mockDaoTest.sObjectMap.put(Id.valueOf('0062w00000KdcZCAAZ'), new Opportunity(AccountId = RSOCL_MockProcessInstanceControllerTest.getFakeId(Account.SObjectType)));

            RSOCL_MultipleApprovalController.processListInstance = mockDaoTest;
            
            Test.startTest();
            List<RSOCL_MultipleApprovalController.SubmittedRecordsWrapper> result = RSOCL_MultipleApprovalController.getSubmittedApprovalRecords();

            System.assertEquals(1, result.size(), 'Result is not correct');
            Test.stopTest();
        } catch (Exception err){
            RSOCL_ExceptionLogger.logError(err, 'RSOCL_MultipleApprovalControllerTest', 'testGetSubmittedApprovalRecords');
            System.assert(false, err.getMessage());
            System.debug('err---' + err.getMessage());
        }
    }

    @isTest
    public static void testProcessRecords(){
        try{
            Test.startTest();
            String lstWorkItemIds = '[{"workItemId":"04i2w000004P4BYAA5","comment":""}]';
            String processType = 'Approve';
            String result = RSOCL_MultipleApprovalController.processRecords(lstWorkItemIds, processType);
            System.assert((result.contains('invalid cross reference id') || result.contains('malformed id')), 'Result is not correct');
            Test.stopTest();
        } catch (Exception err){
            RSOCL_ExceptionLogger.logError(err, 'RSOCL_MultipleApprovalControllerTest', 'testProcessRecords');
            System.assert(false, err.getMessage());
            System.debug('err---' + err.getMessage());
        }
    }

}