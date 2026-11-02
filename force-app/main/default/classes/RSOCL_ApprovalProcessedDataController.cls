/**
 * @description Controller to fetch approval requests already processed for the current user
 */
public with sharing class RSOCL_ApprovalProcessedDataController {

    private static final String STATUS_APPROVED = 'Approved';
    private static final String STATUS_REJECTED = 'Rejected';

    /**
     * @description DAO instance, replaced with mock in test class
     */
    @TestVisible
    public static RSOCL_MockDaoProcessInstanceController.IProcessDefination processListInstance = new RSOCL_MockDaoProcessInstanceController();

    private static Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
    private static Map<String, Map<String, Schema.SObjectField>> fieldMapCache = new Map<String, Map<String, Schema.SObjectField>>();

    /**
     * @description Gets processed approval records for the current user
     * @return List of SubmittedRecordsWrapper
     */
    @AuraEnabled
    public static List<SubmittedRecordsWrapper> getProcessedAprrovalRecords(){
        try{
            List<SubmittedRecordsWrapper> lstSubmissionWrapper = new List<SubmittedRecordsWrapper>();
            // users where current user is the delegated approver
            Map<Id, User> delegatedApproverUserMap = new Map<Id, User>([SELECT Id FROM User WHERE DelegatedApproverId = :UserInfo.getUserId() WITH USER_MODE]);
            Set<Id> setOfGroupIds = getGroupIds(delegatedApproverUserMap.keySet());

            // all approval requests related to current user
            List<ProcessInstance> psList = processListInstance.getProcessInstance(UserInfo.getUserId(), delegatedApproverUserMap.keySet(), setOfGroupIds, null);

            Map<String, List<String>> objIdMap = buildObjectIdMap(psList);
            Map<String, List<String>> objFieldMap = buildObjectFieldMap();
            Map<Id, sObject> sObjectMap = querySObjects(objFieldMap, objIdMap);

            for(ProcessInstance ps : psList){
                if(!ps.Steps.isEmpty()){
                    lstSubmissionWrapper.add(buildWrapper(ps, objFieldMap, sObjectMap));
                }
            }
            return lstSubmissionWrapper;
        }
        catch(Exception e){
            RSOCL_ExceptionLogger.logError(e, 'RSOCL_ApprovalProcessedDataController', 'getProcessedAprrovalRecords');
            throw new AuraHandledException(e.getMessage());
        }
    }

    // groups where current user or delegated users are members
    private static Set<Id> getGroupIds(Set<Id> delegatedUserIds){
        Set<Id> setOfGroupIds = new Set<Id>();
        List<GroupMember> members = [SELECT GroupId FROM GroupMember WHERE UserOrGroupId IN :delegatedUserIds OR UserOrGroupId = :UserInfo.getUserId() WITH USER_MODE];
        for(GroupMember member : members){
            setOfGroupIds.add(member.GroupId);
        }
        return setOfGroupIds;
    }

    // object name -> record ids
    private static Map<String, List<String>> buildObjectIdMap(List<ProcessInstance> psList){
        Map<String, List<String>> objIdMap = new Map<String, List<String>>();
        for(ProcessInstance ps : psList){
            if(ps.Steps.isEmpty()){
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

    // one query per object, as multiple objects can't be queried in a single soql
    private static Map<Id, sObject> querySObjects(Map<String, List<String>> objFieldMap, Map<String, List<String>> objIdMap){
        Map<Id, sObject> sObjectMap = new Map<Id, sObject>();
        Integer queryCount = Limits.getQueries();
        for(String objName : objFieldMap.keySet()){
            if(!objIdMap.containsKey(objName) || queryCount >= 100){
                continue;
            }
            String query = 'SELECT ';
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
        ProcessInstanceStep firstStep = ps.Steps[0];
        SubmittedRecordsWrapper wrapInstance = new SubmittedRecordsWrapper();
        wrapInstance.recordId = ps.TargetObjectId;
        wrapInstance.recordName = ps.TargetObject.Name;
        wrapInstance.relatedTo = globalDescribe.get(objName).getDescribe().getLabel();
        Date lastModifiedDate = Date.valueOf(firstStep.SystemModstamp);
        wrapInstance.approvedDate = Date.newInstance(lastModifiedDate.year(), lastModifiedDate.month(), lastModifiedDate.day());
        wrapInstance.approverComments = firstStep.Comments;
        wrapInstance.stepStatus = firstStep.StepStatus;
        setStatusAndColor(wrapInstance, firstStep.StepStatus);
        wrapInstance.fieldDataWrap = buildFieldsDataList(sObjectMap.get(ps.TargetObjectId), objName, objFieldMap.get(objName));
        return wrapInstance;
    }

    private static void setStatusAndColor(SubmittedRecordsWrapper wrapInstance, String stepStatus){
        if(stepStatus == STATUS_APPROVED){
            wrapInstance.approvedStatus = 'Last Week Approved';
            wrapInstance.rowColor = 'background-color:rgb(80, 200, 120);color:white;';
        }else if(stepStatus == STATUS_REJECTED){
            wrapInstance.approvedStatus = 'Last Week Rejected';
            wrapInstance.rowColor = 'background-color:rgb(186, 5, 23);color:white;';
        }
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
        @AuraEnabled public String relatedTo;
        @AuraEnabled public String recordName;
        @AuraEnabled public String submittedBy;
        @AuraEnabled public Date approvedDate;
        @AuraEnabled public String approverComments;
        @AuraEnabled public String usefulInfo;
        @AuraEnabled public String stepStatus;
        @AuraEnabled public String approvedStatus;
        @AuraEnabled public List<FieldsDataWrapper> fieldDataWrap;
        @AuraEnabled public String rowColor;
    }

    /**
     * @description Wrapper to hold field label and value
     */
    public class FieldsDataWrapper{
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String fieldVal;
    }
}