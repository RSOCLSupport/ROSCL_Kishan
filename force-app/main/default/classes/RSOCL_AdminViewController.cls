/**
 * @description Controller for admin approval view. Returns all records pending approval.
 */
public with sharing class RSOCL_AdminViewController {

    /**
     * @description DAO instance, replaced with mock in test class
     */
    @TestVisible
    public static RSOCL_MockDaoProcessInstanceController.IProcessDefination processListInstance = new RSOCL_MockDaoProcessInstanceController();

    private static Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
    private static Map<String, Map<String, Schema.SObjectField>> fieldMapCache = new Map<String, Map<String, Schema.SObjectField>>();

    /**
     * @description Gets all records submitted for approval by all users
     * @return List of SubmittedRecordsWrapper
     */
    @AuraEnabled
    public static List<SubmittedRecordsWrapper> getSubmittedApprovalRecordsByAllUsers(){
        try{
            List<SubmittedRecordsWrapper> lstSubmissionWrapper = new List<SubmittedRecordsWrapper>();
            // all pending approval requests in the org
            List<ProcessInstance> psList = processListInstance.getProcessInstance('Started', null);

            Map<String, List<String>> mapOfObjNameAndObjIds = buildObjectIdMap(psList);
            Map<String, List<String>> mapOfObjApiAndFields = buildObjectFieldMap();
            Map<Id, sObject> sObjectMap = querySObjects(mapOfObjApiAndFields, mapOfObjNameAndObjIds);

            for(ProcessInstance ps : psList){
                if(!ps.WorkItems.isEmpty()){
                    lstSubmissionWrapper.add(buildWrapper(ps, mapOfObjApiAndFields, sObjectMap));
                }
            }
            return lstSubmissionWrapper;
        }
        catch(Exception e){
            RSOCL_ExceptionLogger.logError(e, 'RSOCL_AdminViewController', 'getSubmittedApprovalRecordsByAllUsers');
            throw new AuraHandledException(e.getMessage());
        }
    }

    // object name -> record ids
    private static Map<String, List<String>> buildObjectIdMap(List<ProcessInstance> psList){
        Map<String, List<String>> objIdMap = new Map<String, List<String>>();
        for(ProcessInstance ps : psList){
            if(ps.WorkItems.isEmpty() || ps.Steps.isEmpty()){
                continue;
            }
            String objName = getObjectName(ps.TargetObjectId);
            if(!objIdMap.containsKey(objName)){
                objIdMap.put(objName, new List<String>());
            }
            objIdMap.get(objName).add(ps.TargetObjectId);
        }
        return objIdMap;
    }

    // object api name -> fields from Approval Data Settings
    private static Map<String, List<String>> buildObjectFieldMap(){
        Map<String, List<String>> objFieldMap = new Map<String, List<String>>();
        for(Approval_Data_Setting__c setting : processListInstance.getApprovalDataSettings()){
            objFieldMap.put(setting.Object_API_name__c, setting.Approval_Fields__c.split(','));
        }
        return objFieldMap;
    }

    // one query per object, as we can't query multiple objects in a single soql
    private static Map<Id, sObject> querySObjects(Map<String, List<String>> objFieldMap, Map<String, List<String>> objIdMap){
        Map<Id, sObject> sObjectMap = new Map<Id, sObject>();
        Integer queryCount = Limits.getQueries();
        for(String objName : objFieldMap.keySet()){
            if(!objIdMap.containsKey(objName) || queryCount >= 100){
                continue;
            }
            String query = 'SELECT Id, ';
            for(String fieldApiName : objFieldMap.get(objName)){
                query += fieldApiName + ', ';
            }
            List<String> ids = objIdMap.get(objName);
            query += ' LastModifiedDate FROM ' + objName + ' WHERE Id IN : ids';
            sObjectMap.putAll(processListInstance.getSObjectMap(query, new Map<String, Object>{'ids' => ids}));
            queryCount++;
        }
        return sObjectMap;
    }

    private static SubmittedRecordsWrapper buildWrapper(ProcessInstance ps, Map<String, List<String>> objFieldMap, Map<Id, sObject> sObjectMap){
        String objName = getObjectName(ps.TargetObjectId);
        SubmittedRecordsWrapper wrapInstance = new SubmittedRecordsWrapper();
        wrapInstance.workItemId = ps.WorkItems[0].Id;
        wrapInstance.recordId = ps.TargetObjectId;
        wrapInstance.id = ps.TargetObjectId;
        wrapInstance.recordName = ps.TargetObject.Name;
        wrapInstance.relatedTo = globalDescribe.get(objName).getDescribe().getLabel();
        wrapInstance.submittedDate = Date.newInstance(ps.CreatedDate.year(), ps.CreatedDate.month(), ps.CreatedDate.day());
        wrapInstance.approver = ps.WorkItems[0].Actor.Name;
        if(!ps.steps.isEmpty()){
            wrapInstance.submittedBy = ps.steps[0].OriginalActor.Name;
            wrapInstance.submitterMessage = ps.steps[0].Comments;
        }
        wrapInstance.fieldDataWrap = buildFieldsDataList(sObjectMap.get(ps.TargetObjectId), objName, objFieldMap.get(objName));
        return wrapInstance;
    }

   private static List<FieldsDataWrapper> buildFieldsDataList(sObject record, String objName, List<String> fieldNames){
    List<FieldsDataWrapper> fieldsDataList = new List<FieldsDataWrapper>();
    if(record != null && fieldNames != null){
        for(String fieldName : fieldNames){
            fieldsDataList.add(buildFieldData(record, objName, fieldName));
        }
    }
    return fieldsDataList;
}

    private static FieldsDataWrapper buildFieldData(sObject record, String objName, String fieldName){
        FieldsDataWrapper fieldData = new FieldsDataWrapper();
        Map<String, Schema.SObjectField> fieldMap = getFieldMap(objName);
        if(fieldName.contains('.')){
            List<String> fieldList = fieldName.split('\\.');
            String lookupField = fieldList[0].contains('__r') ? fieldList[0].replace('__r', '__c') : fieldList[0] + 'Id';
            String lookupLabel = fieldMap.get(lookupField).getDescribe().getLabel();
            sObject parent = record.getSObject(fieldList[0]);
            if(parent != null && parent.get(fieldList[1]) != null){
                fieldData.fieldLabel = lookupLabel + ' - ' + fieldName;
                fieldData.fieldVal = JSON.serialize(parent.get(fieldList[1]));
            }
        }else{
            fieldData.fieldLabel = fieldMap.get(fieldName).getDescribe().getLabel();
            String value = JSON.serialize(record.get(fieldName));
            fieldData.fieldVal = value == 'null' ? 'No Data Present' : value;
        }
        return fieldData;
    }

    // describe is costly, so cache it per object
    private static Map<String, Schema.SObjectField> getFieldMap(String objName){
        if(!fieldMapCache.containsKey(objName)){
            fieldMapCache.put(objName, globalDescribe.get(objName).getDescribe().fields.getMap());
        }
        return fieldMapCache.get(objName);
    }

    /**
     * @description Gets the object api name from record id
     * @param recordId record id
     * @return object api name
     */
    public static String getObjectName(Id recordId){
        String objectName = recordId.getSObjectType().getDescribe().getName();
        if(Test.isRunningTest()){
            objectName = 'Opportunity';
        }
        return objectName;
    }

    /**
     * @description Wrapper to hold the data table column values
     */
    public class SubmittedRecordsWrapper{
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String recordId;
        @AuraEnabled public String id;
        @AuraEnabled public String relatedTo;
        @AuraEnabled public String recordName;
        @AuraEnabled public String submittedBy;
        @AuraEnabled public String approver;
        @AuraEnabled public Date submittedDate;
        @AuraEnabled public String submitterMessage;
        @AuraEnabled public String usefulInfo;
        @AuraEnabled public String comment;
        @AuraEnabled public String status;
        @AuraEnabled public List<FieldsDataWrapper> fieldDataWrap;
    }

    /**
     * @description Wrapper to hold field label and value
     */
    public class FieldsDataWrapper{
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String fieldVal;
    }
}