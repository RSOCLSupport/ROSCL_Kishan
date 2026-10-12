/**
 * @description DAO class for approval process data. It is used as the real data source
 * and can be replaced by a mock in test classes through the IProcessDefination interface.
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ExcessiveParameterList')
public with sharing class RSOCL_MockDaoProcessInstanceController implements IProcessDefination {

    /**
     * @description Interface for fetching approval process related data
     */
    public interface IProcessDefination {

        /**
         * @description Gets process definitions by state and type
         * @param state process state, e.g. Active
         * @param type process type, e.g. Approval
         * @return List of ProcessDefinition
         */
        List<ProcessDefinition> getObjects(String state, String type);

        /**
         * @description Gets approval data settings of an object
         * @param objectName object api name
         * @return List of Approval_Data_Setting__c
         */
        List<Approval_Data_Setting__c> getApprovalDataSettings(String objectName);

        /**
         * @description Gets all approval data settings
         * @return List of Approval_Data_Setting__c
         */
        List<Approval_Data_Setting__c> getApprovalDataSettings();

        /**
         * @description Gets process instances with work items and steps of the given step status
         * @param userId current user id
         * @param delegateUserSet users for whom current user is delegated approver
         * @param setOfGroupIds group ids of the user
         * @param stepStatus step status filter
         * @param lastActorId last actor id filter
         * @return List of ProcessInstance
         */
        List<ProcessInstance> getProcessInstance(Id userId, Set<Id> delegateUserSet, Set<Id> setOfGroupIds, String stepStatus, Id lastActorId);

        /**
         * @description Gets approved and rejected process instances of the last 7 days
         * @param userId current user id
         * @param delegateUserSet users for whom current user is delegated approver
         * @param setOfGroupIds group ids of the user
         * @param lastActorId last actor id to exclude
         * @return List of ProcessInstance
         */
        List<ProcessInstance> getProcessInstance(Id userId, Set<Id> delegateUserSet, Set<Id> setOfGroupIds, Id lastActorId);

        /**
         * @description Gets process instances with recent work items for all users
         * @param stepStatus step status filter
         * @param lastActorId last actor id filter
         * @return List of ProcessInstance
         */
        List<ProcessInstance> getProcessInstance(String stepStatus, Id lastActorId);

        /**
         * @description Runs a dynamic query and returns the result as a map
         * @param query soql query string
         * @param bindMap bind variable names and values
         * @return Map of record id to sObject
         */
        Map<Id, sObject> getSObjectMap(String query, Map<String, Object> bindMap);
    }

    /**
     * @description Gets process definitions by state and type
     * @param state process state, e.g. Active
     * @param type process type, e.g. Approval
     * @return List of ProcessDefinition
     */
    public List<ProcessDefinition> getObjects(String state, String type){
        return [SELECT Id, Name, State, TableEnumOrId, Type
                FROM ProcessDefinition
                WHERE State = :state AND Type = :type];
    }

    /**
     * @description Gets approval data settings of an object
     * @param objectName object api name
     * @return List of Approval_Data_Setting__c
     */
    public List<Approval_Data_Setting__c> getApprovalDataSettings(String objectName){
        return [SELECT Id, Name
                FROM Approval_Data_Setting__c
                WHERE Object_API_name__c = :objectName];
    }

    /**
     * @description Gets all approval data settings
     * @return List of Approval_Data_Setting__c
     */
    public List<Approval_Data_Setting__c> getApprovalDataSettings(){
        return [SELECT Id, Object_API_name__c, Approval_Fields__c FROM Approval_Data_Setting__c];
    }

    /**
     * @description Gets process instances with work items and steps of the given step status
     * @param userId current user id
     * @param delegateUserSet users for whom current user is delegated approver
     * @param setOfGroupIds group ids of the user
     * @param stepStatus step status filter
     * @param lastActorId last actor id filter
     * @return List of ProcessInstance
     */
    public List<ProcessInstance> getProcessInstance(Id userId, Set<Id> delegateUserSet, Set<Id> setOfGroupIds, String stepStatus, Id lastActorId){
        return [SELECT Id, TargetObjectId, TargetObject.Name, CreatedDate,
                (SELECT Id, OriginalActorId FROM WorkItems
                 WHERE OriginalActorId = :userId OR OriginalActorId IN :delegateUserSet OR OriginalActorId IN :setOfGroupIds),
                (SELECT OriginalActor.Name, Comments FROM Steps WHERE StepStatus = :stepStatus)
                FROM ProcessInstance
                WHERE LastActorId = :lastActorId
                ORDER BY LastModifiedDate DESC];
    }

    /**
     * @description Gets approved and rejected process instances of the last 7 days
     * @param userId current user id
     * @param delegateUserSet users for whom current user is delegated approver
     * @param setOfGroupIds group ids of the user
     * @param lastActorId last actor id to exclude
     * @return List of ProcessInstance
     */
    public List<ProcessInstance> getProcessInstance(Id userId, Set<Id> delegateUserSet, Set<Id> setOfGroupIds, Id lastActorId){
        return [SELECT Id, TargetObjectId, TargetObject.Name, CreatedDate,
                (SELECT OriginalActor.Name, Comments, StepStatus, SystemModstamp FROM Steps
                 WHERE (StepStatus = 'Approved' OR StepStatus = 'Rejected')
                 AND (ActorId = :userId OR OriginalActorId IN :delegateUserSet OR OriginalActorId IN :setOfGroupIds)
                 AND SystemModstamp >= :System.now() - 7)
                FROM ProcessInstance
                WHERE LastActorId != :lastActorId
                ORDER BY LastModifiedDate DESC];
    }

    /**
     * @description Gets process instances with recent work items for all users
     * @param stepStatus step status filter
     * @param lastActorId last actor id filter
     * @return List of ProcessInstance
     */
    public List<ProcessInstance> getProcessInstance(String stepStatus, Id lastActorId){
        return [SELECT Id, TargetObjectId, TargetObject.Name, CreatedDate,
                (SELECT Id, Actor.Name FROM WorkItems WHERE SystemModstamp >= :System.now() - 7),
                (SELECT OriginalActor.Name, Actor.Name, Comments FROM Steps WHERE StepStatus = :stepStatus)
                FROM ProcessInstance
                WHERE LastActorId = :lastActorId
                ORDER BY LastModifiedDate];
    }

    /**
     * @description Runs a dynamic query and returns the result as a map
     * @param query soql query string
     * @param bindMap bind variable names and values
     * @return Map of record id to sObject
     */
    public Map<Id, sObject> getSObjectMap(String query, Map<String, Object> bindMap){
        return new Map<Id, sObject>((List<sObject>)Database.queryWithBinds(query, bindMap, System.AccessLevel.SYSTEM_MODE));
    }
}