/**
 * @description Controller to show and approve/reject the records pending approval of the current user
 */
public with sharing class RSOCL_MultipleApprovalController {

    private static final String STYLE_DELEGATED = 'color:rgb(204, 85, 0);';
    private static final String STYLE_OWN = 'color:rgb(1, 118, 211);';

    /**
     * @description DAO instance, replaced with mock in test class
     */
    @TestVisible
    public static RSOCL_MockDaoProcessInstanceController.IProcessDefination processListInstance = new RSOCL_MockDaoProcessInstanceController();

    private static Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
    private static Map<String, Map<String, Schema.SObjectField>> fieldMapCache = new Map<String, Map<String, Schema.SObjectField>>();

    /**
     * @description Gets all the records submitted for approval to the current user
     * @return List of SubmittedRecordsWrapper
     */
    @AuraEnabled
    public static List<SubmittedRecordsWrapper> getSubmittedApprovalRecords(){
        try{
            List<SubmittedRecordsWrapper> lstSubmissionWrapper = new List<SubmittedRecordsWrapper>();
            // users where current user is the delegated approver
            Map<Id, User> delegatedApproverUserMap = new Map<Id, User>([SELECT Id FROM User WHERE DelegatedApproverId = :UserInfo.getUserId() WITH USER_MODE]);
            Set<Id> setOfGroupIds = getGroupIds(delegatedApproverUserMap.keySet());

            // all approval requests related to current user
            List<ProcessInstance> psList = processListInstance.getProcessInstance(UserInfo.getUserId(), delegatedApproverUserMap.keySet(), setOfGroupIds, 'Started', null);

            Map<String, List<String>> objIdMap = buildObjectIdMap(psList);
            Map<String, List<String>> objFieldMap = buildObjectFieldMap();
            Map<Id, sObject> sObjectMap = querySObjects(objFieldMap, objIdMap);

            for(ProcessInstance ps : psList){
                if(!ps.WorkItems.isEmpty()){
                    SubmittedRecordsWrapper wrapInstance = buildWrapper(ps, objFieldMap, sObjectMap);
                    wrapInstance.textStyle = getTextStyle(ps, delegatedApproverUserMap);
                    lstSubmissionWrapper.add(wrapInstance);
                }
            }
            return lstSubmissionWrapper;
        }
        catch(Exception e){
            RSOCL_ExceptionLogger.logError(e, 'RSOCL_MultipleApprovalController', 'getSubmittedApprovalRecords');
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Approves or rejects the selected work items
     * @param lstWorkItemIds JSON string of work item ids with comments
     * @param processType Approve or Reject
     * @return Message with the result of the processing
     */
    @AuraEnabled
    public static String processRecords(String lstWorkItemIds, String processType){
        try{
            List<ProcessApprvolWrapper> approvals = (List<ProcessApprvolWrapper>)System.JSON.deserialize(lstWorkItemIds, List<ProcessApprvolWrapper>.class);
            String message = '';
            Integer recordsProcessed = 0;
            String comments = processType == 'Approve' ? 'Approved' : 'Rejected';
            // ProcessWorkitemRequest has methods to programmatically process submitted records
            List<Approval.ProcessWorkitemRequest> lstWorkItemRequest = new List<Approval.ProcessWorkitemRequest>();
            for(ProcessApprvolWrapper workItem : approvals){
                Approval.ProcessWorkitemRequest objWorkItemRequest = new Approval.ProcessWorkitemRequest();
                objWorkItemRequest.setComments(workItem.comment);
                objWorkItemRequest.setAction(processType);
                objWorkItemRequest.setWorkitemId(workItem.workItemId);
                lstWorkItemRequest.add(objWorkItemRequest);
            }
            Approval.ProcessResult[] lstProcessResult = Approval.process(lstWorkItemRequest, false);
            for(Approval.ProcessResult processResult : lstProcessResult){
                if(processResult.isSuccess()){
                    recordsProcessed++;
                }else{
                    message += getErrorMessages(processResult);
                }
            }
            if(recordsProcessed == approvals.size()){
                message = 'All records are ' + comments + ' successfully';
            }
            return message;
        }
        catch(Exception e){
            RSOCL_ExceptionLogger.logError(e, 'RSOCL_MultipleApprovalController', 'processRecords');
            throw new AuraHandledException(e.getMessage());
        }
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

    // delegated approvals are shown in a different color
    private static String getTextStyle(ProcessInstance ps, Map<Id, User> delegatedApproverUserMap){
        return delegatedApproverUserMap.containsKey(ps.WorkItems[0].OriginalActorId) ? STYLE_DELEGATED : STYLE_OWN;
    }

    // joins all error messages of a failed approval result
    private static String getErrorMessages(Approval.ProcessResult processResult){
        String errors = '';
        for(Database.Error error : processResult.getErrors()){
            errors += error.getMessage() + '\n\n';
        }
        return errors;
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
            List<String> fields = new List<String>();
            if(String.isNotEmpty(setting.Approval_Fields__c)){
                fields = setting.Approval_Fields__c.split(',');
            }
            objFieldMap.put(setting.Object_API_name__c, fields);
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
        SubmittedRecordsWrapper wrapInstance = new SubmittedRecordsWrapper();
        wrapInstance.workItemId = ps.WorkItems[0].Id;
        wrapInstance.recordId = ps.TargetObjectId;
        wrapInstance.id = ps.TargetObjectId;
        wrapInstance.recordName = ps.TargetObject.Name;
        wrapInstance.relatedTo = globalDescribe.get(objName).getDescribe().getLabel();
        wrapInstance.submittedDate = Date.newInstance(ps.CreatedDate.year(), ps.CreatedDate.month(), ps.CreatedDate.day());
        if(!ps.steps.isEmpty()){
            wrapInstance.submittedBy = ps.steps[0].OriginalActor.Name;
            wrapInstance.submitterMessage = ps.steps[0].Comments;
        }
        wrapInstance.usefulInfo = '';
        wrapInstance.comment = '';
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
        Map<String, Schema.SObjectField> fieldMap = getFieldMap(objName);
        if(fieldName.contains('.')){
            return buildCrossObjectFieldData(record, fieldMap, fieldName);
        }
        return buildDirectFieldData(record, fieldMap, fieldName);
    }

    // field of the same object, e.g. Amount
    private static FieldsDataWrapper buildDirectFieldData(sObject record, Map<String, Schema.SObjectField> fieldMap, String fieldName){
        FieldsDataWrapper fieldData = new FieldsDataWrapper();
        fieldData.fieldLabel = fieldMap.get(fieldName).getDescribe().getLabel();
        String value = JSON.serialize(record.get(fieldName));
        fieldData.fieldVal = value == 'null' ? 'No Data Present' : value;
        return fieldData;
    }

    // field of a related object, e.g. Account.Name
    private static FieldsDataWrapper buildCrossObjectFieldData(sObject record, Map<String, Schema.SObjectField> fieldMap, String fieldName){
        FieldsDataWrapper fieldData = new FieldsDataWrapper();
        List<String> fieldList = fieldName.split('\\.');
        String lookupField = fieldList[0].contains('__r') ? fieldList[0].replace('__r', '__c') : fieldList[0] + 'Id';
        String lookupLabel = fieldMap.get(lookupField).getDescribe().getLabel();
        sObject parent = record.getSObject(fieldList[0]);
        if(parent != null && parent.get(fieldList[1]) != null){
            fieldData.fieldLabel = lookupLabel + ' - ' + fieldName;
            fieldData.fieldVal = JSON.serialize(parent.get(fieldList[1]));
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
     * @description Wrapper to hold the data table column values
     */
    public class SubmittedRecordsWrapper{
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String recordId;
        @AuraEnabled public String id;
        @AuraEnabled public String relatedTo;
        @AuraEnabled public String recordName;
        @AuraEnabled public String submittedBy;
        @AuraEnabled public Date submittedDate;
        @AuraEnabled public String submitterMessage;
        @AuraEnabled public String usefulInfo;
        @AuraEnabled public String comment;
        @AuraEnabled public List<FieldsDataWrapper> fieldDataWrap;
        @AuraEnabled public String textStyle;
    }

    /**
     * @description Wrapper to hold work item id and comment sent from the component
     */
    public class ProcessApprvolWrapper{
        @AuraEnabled public String workItemId;
        @AuraEnabled public String comment;
    }

    /**
     * @description Wrapper to hold field label and value
     */
    public class FieldsDataWrapper{
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String fieldVal;
    }
}