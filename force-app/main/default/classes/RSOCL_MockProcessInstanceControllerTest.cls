/**
 * @description Mock DAO used in test classes in place of RSOCL_MockDaoProcessInstanceController
 */
public with sharing class RSOCL_MockProcessInstanceControllerTest implements RSOCL_MockDaoProcessInstanceController.IProcessDefination {

    /**
     * @description Counter used to generate fake record ids
     */
    public static Integer sNum = 1;

    /**
     * @description Process definitions returned by getObjects
     */
    public List<ProcessDefinition> processDefination = new List<ProcessDefinition>();

    /**
     * @description Approval data settings returned by getApprovalDataSettings
     */
    public List<Approval_Data_Setting__c> approvalDataSettingList = new List<Approval_Data_Setting__c>();

    /**
     * @description Process instances returned by getProcessInstance
     */
    public List<ProcessInstance> processInstanceList = new List<ProcessInstance>();

    /**
     * @description Records returned by getSObjectMap
     */
    public Map<Id, sObject> sObjectMap = new Map<Id, sObject>();

    /**
     * @description Returns the mock process definitions
     * @param state process state
     * @param type process type
     * @return List of ProcessDefinition
     */
    public List<ProcessDefinition> getObjects(String state, String type){
        return processDefination;
    }

    /**
     * @description Returns the mock approval data settings of an object
     * @param objectName object api name
     * @return List of Approval_Data_Setting__c
     */
    public List<Approval_Data_Setting__c> getApprovalDataSettings(String objectName){
        return approvalDataSettingList;
    }

    /**
     * @description Returns all the mock approval data settings
     * @return List of Approval_Data_Setting__c
     */
    public List<Approval_Data_Setting__c> getApprovalDataSettings(){
        return approvalDataSettingList;
    }

    /**
     * @description Returns the mock process instances
     * @param userId current user id
     * @param delegateUserSet delegated user ids
     * @param setOfGroupIds group ids
     * @param stepStatus step status filter
     * @param lastActorId last actor id filter
     * @return List of ProcessInstance
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public List<ProcessInstance> getProcessInstance(Id userId, Set<Id> delegateUserSet, Set<Id> setOfGroupIds, String stepStatus, Id lastActorId){
        return processInstanceList;
    }

    /**
     * @description Returns the mock process instances
     * @param userId current user id
     * @param delegateUserSet delegated user ids
     * @param setOfGroupIds group ids
     * @param lastActorId last actor id filter
     * @return List of ProcessInstance
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public List<ProcessInstance> getProcessInstance(Id userId, Set<Id> delegateUserSet, Set<Id> setOfGroupIds, Id lastActorId){
        return processInstanceList;
    }

    /**
     * @description Returns the mock process instances
     * @param stepStatus step status filter
     * @param lastActorId last actor id filter
     * @return List of ProcessInstance
     */
    public List<ProcessInstance> getProcessInstance(String stepStatus, Id lastActorId){
        return processInstanceList;
    }

    /**
     * @description Returns the mock record map
     * @param query soql query string
     * @param bindMap bind variable names and values
     * @return Map of record id to sObject
     */
    public Map<Id, sObject> getSObjectMap(String query, Map<String, Object> bindMap){
        return sObjectMap;
    }

    /**
     * @description Generates a fake record id for the given object type
     * @param sot object type
     * @return fake record id
     */
    public static String getFakeId(Schema.SObjectType sot){
        String result = String.valueOf(sNum++);
        return sot.getDescribe().getKeyPrefix() +
            '0'.repeat(12 - result.length()) + result;
    }
}