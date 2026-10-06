public with sharing class RSOCL_MockProcessInstanceControllerTest implements RSOCL_MockDaoProcessInstanceController.IProcessDefination {
    public static Integer s_num = 1;
    public List<ProcessDefinition> processDefination = new List<ProcessDefinition>();
    public List<Approval_Data_Setting__c> approvalDataSettingList = new List<Approval_Data_Setting__c>();
    public List<ProcessInstance> processInstanceList = new List<ProcessInstance>();
    public Map<Id, sObject> sObjectMap = new Map<Id, sObject>();

    public List<ProcessDefinition> getObjects(String state, String type){
        return processDefination;
    }

    public List<Approval_Data_Setting__c> getApprovalDataSettings(String objectName){
        return approvalDataSettingList;
    }

    public List<Approval_Data_Setting__c> getApprovalDataSettings(){
        return approvalDataSettingList;
    }

    public List<ProcessInstance> getProcessInstance(Id userId, Set<Id> delegateUserSet, Set<Id> setOfGroupIds, String StepStatus, Id LastActorId){
        return processInstanceList;
    }

    public List<ProcessInstance> getProcessInstance(Id userId, Set<Id> delegateUserSet, Set<Id> setOfGroupIds, Id LastActorId){
        return processInstanceList;
    }

    public List<ProcessInstance> getProcessInstance(String StepStatus, Id LastActorId){
        return processInstanceList;
    }

    public Map<Id, sObject> getSObjectMap(String query, Map<String, Object> bindMap){
        return sObjectMap;
    }

    public static String getFakeId(Schema.SObjectType sot)
    {
        String result = String.valueOf(s_num++);
        return sot.getDescribe().getKeyPrefix() + 
            '0'.repeat(12-result.length()) + result;
    }
}