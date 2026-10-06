@isTest
public with sharing class RSOCL_AdminViewControllerTest {
    @isTest
    public static void testGetSubmittedApprovalRecordsByAllUsers(){
        try{
            RSOCL_MockProcessInstanceControllerTest mockDaoTest = new RSOCL_MockProcessInstanceControllerTest();
            RSOCL_MockDaoProcessInstanceController mockDao = new RSOCL_MockDaoProcessInstanceController();
            mockDao.getProcessInstance(null, null);
            mockDao.getApprovalDataSettings();

            String processInstanceData = '{"Id":"04g2w000003rbSHAAZ","TargetObjectId":"a012w00001DQmGSAA2","CreatedDate":"2023-03-11T09:20:50.000Z", ' + 
                                     '"Workitems": {"totalSize": "1","done": true, "records":[{"ProcessInstanceId":"04g2w000003rbSHAAZ","Id":"04i2w000004P4BYAA0","OriginalActorId":"0052w00000DyipuAAB"}]},' + 
                                     '"Steps":{"totalSize": "1","done": true, "records":[{"ProcessInstanceId":"04g2w000003rbSHAAY","Id":"04h2w000005Nd8ZAAS","OriginalActorId":"0052w00000DyipuAAA","Comments":"asdasd", "StepStatus":"Approved", "SystemModstamp":"2023-03-11T09:20:50.000Z"}]}}';
            String sObjectMapData = '{"a012w00001DQmGSAA2":{"Id":"a012w00001DQmGSAA2", "LastModifiedDate":"2023-03-11T09:20:50.000Z"}}';

            ProcessInstance processInstance = (ProcessInstance)JSON.deserialize(processInstanceData, ProcessInstance.class);
            Map<Id, sObject> sObjectMap = new Map<Id, sObject>();
            Opportunity opp = new Opportunity();
            sObjectMap.put('a012w00001DQmGSAA2', opp);

            Approval_Data_Setting__c testApprovalData = new Approval_Data_Setting__c(Id = RSOCL_MockProcessInstanceControllerTest.getFakeId(Approval_Data_Setting__c.SObjectType), Approval_Fields__c = 'AccountId', Object_API_name__c = 'Opportunity');

            mockDaoTest.processInstanceList.add(processInstance);
            mockDaoTest.approvalDataSettingList.add(testApprovalData);
            mockDaoTest.sObjectMap = sObjectMap;

            RSOCL_AdminViewController.processListInstance = mockDaoTest;
            
            Test.startTest();
            List<RSOCL_AdminViewController.SubmittedRecordsWrapper> result = RSOCL_AdminViewController.getSubmittedApprovalRecordsByAllUsers();

            System.assertEquals(1, result.size(), 'Result is not correct');
            Test.stopTest();
        } catch (Exception err){
            System.debug('err---' + err.getMessage()+err.getLineNumber());
            RSOCL_ExceptionLogger.logError(err, 'RSOCL_AdminViewControllerTest', 'testGetSubmittedApprovalRecordsByAllUsers');
            System.assert(false, err.getMessage());            
        }
    }
}