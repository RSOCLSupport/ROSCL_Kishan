public with sharing class RSOCL_MockDaoProcessInstanceController implements IProcessDefination{
    public interface IProcessDefination{
        List<ProcessDefinition> getObjects(String state, String type);
        List<Approval_Data_Setting__c> getApprovalDataSettings(String objectName);
        List<Approval_Data_Setting__c> getApprovalDataSettings();
        List<ProcessInstance> getProcessInstance(Id userId, Set<Id> delegateUserSet, Set<Id> setOfGroupIds, String StepStatus, Id LastActorId);
        List<ProcessInstance> getProcessInstance(Id userId, Set<Id> delegateUserSet, Set<Id> setOfGroupIds, Id LastActorId);
        List<ProcessInstance> getProcessInstance(String StepStatus, Id LastActorId);
        Map<Id, sObject> getSObjectMap(String query, Map<String, Object> bindMap);
    }

    public List<ProcessDefinition> getObjects(String state, String type){
        return [SELECT Id, Name, State, TableEnumOrId, Type
                FROM ProcessDefinition
                WHERE State = :state AND Type = :type];
    }

    public List<Approval_Data_Setting__c> getApprovalDataSettings(String objectName){
        return [SELECT Id, Name
                FROM Approval_Data_Setting__c
                WHERE Object_API_name__c = :objectName];
    }

    public List<Approval_Data_Setting__c> getApprovalDataSettings(){
        return [SELECT Id,Object_API_name__c,Approval_Fields__c FROM Approval_Data_Setting__c];
    }
    
    public List<ProcessInstance> getProcessInstance(Id userId, Set<Id> delegateUserSet, Set<Id> setOfGroupIds, String StepStatus, Id LastActorId){
        return [SELECT Id,TargetObjectId,TargetObject.Name,CreatedDate,(SELECT ID,OriginalActorId FROM WorkItems WHERE
        OriginalActorId = : userId OR OriginalActorId In : delegateUserSet OR 
        OriginalActorId In : setOfGroupIds),(SELECT OriginalActor.Name,Comments FROM Steps WHERE
        StepStatus = :StepStatus) FROM ProcessInstance WHERE LastActorId= :LastActorId ORDER BY
        LastModifiedDate DESC];
    }

    public List<ProcessInstance> getProcessInstance(Id userId, Set<Id> delegateUserSet, Set<Id> setOfGroupIds, Id LastActorId){
        return [SELECT Id,TargetObjectId,TargetObject.Name,CreatedDate,(SELECT OriginalActor.Name,Comments,StepStatus,SystemModstamp FROM Steps WHERE
        (StepStatus = 'Approved' OR  StepStatus = 'Rejected') AND (ActorId = : userId OR OriginalActorId IN : delegateUserSet OR 
        OriginalActorId IN : setOfGroupIds) AND SystemModstamp>=: system.now()-7) FROM ProcessInstance WHERE LastActorId!= : LastActorId ORDER BY
        LastModifiedDate DESC];
    }
    
    public List<ProcessInstance> getProcessInstance(String StepStatus, Id LastActorId){
        return [SELECT Id,TargetObjectId,TargetObject.Name,CreatedDate,(SELECT Id,Actor.Name FROM WorkItems WHERE SystemModstamp>=: system.now()-7 ),(SELECT OriginalActor.Name,Actor.Name,Comments FROM Steps WHERE
        StepStatus = :StepStatus) FROM ProcessInstance WHERE LastActorId=:LastActorId ORDER BY
        LastModifiedDate];
    }

    public Map<Id, sObject> getSObjectMap(String query, Map<String, Object> bindMap){
        return (new Map<Id, sObject>((List<sObject>)Database.queryWithBinds(query, bindMap, System.AccessLevel.SYSTEM_MODE)));
    }
}