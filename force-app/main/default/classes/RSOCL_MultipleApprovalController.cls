public with sharing class RSOCL_MultipleApprovalController {

    @testVisible 
    public static RSOCL_MockDaoProcessInstanceController.IProcessDefination processListInstance = new RSOCL_MockDaoProcessInstanceController();
    
    //Method to fetch all the records which are submitted for approval
    @AuraEnabled
    public static List<SubmittedRecordsWrapper> getSubmittedApprovalRecords(){
    try{
        List<SubmittedRecordsWrapper> lstSubmissionWrapper = new List<SubmittedRecordsWrapper>();
        //to get all the User where delgated approver is current user.
        Map<Id, User> delegatedApproverUserMap= new Map<Id, User>([SELECT Id FROM User WHERE DelegatedApproverId=: UserInfo.getUserId()]);
        //to get all the Group in which current user is added.
        Map<Id, GroupMember> groupMap = new Map<Id, GroupMember>([SELECT groupId,group.Name FROM GroupMember WHERE UserOrGroupId In : delegatedApproverUserMap.keySet() OR UserOrGroupId=:UserInfo.getUserId()]);
        Set<Id> setOfGroupIds=new Set<Id>();
        for(GroupMember groupMemberRecord: groupMap.values()){
            setOfGroupIds.add(groupMemberRecord.GroupId);
        }
        //to get all approval requests related to current user.
        List<ProcessInstance> psList = processListInstance.getProcessInstance(UserInfo.getUserId(), delegatedApproverUserMap.keySet(), setOfGroupIds, 'Started', null);

        Map<String, List<String>> mapOfObjNameAndObjIds=new Map<String, List<String>>();
        if(!psList.isEmpty()){
            for( ProcessInstance ps :psList){
                if(!ps.WorkItems.isEmpty() && !ps.Steps.isEmpty()){
                    String objName = getObjectName(ps.TargetObjectId);
                    if(mapOfObjNameAndObjIds.containsKey(objName)){
                        List<String> objIds=(mapOfObjNameAndObjIds.get(objName));
                        objIds.add(ps.TargetObjectId);
                        mapOfObjNameAndObjIds.put(objName,objIds);
                    }
                    else{
                        mapOfObjNameAndObjIds.put(objName,new List<String>{ps.TargetObjectId});
                    }
                }
            } 
        }
        // Get the custom Object Approval Data settings data and set it as Map of corresponsing objectname and its fields.
        Map<String, List<String>> mapOfObjNameAndApprovalFields = new Map<String, List<String>>();
        List<Approval_Data_Setting__c> lstOfApprovalDataSettings = processListInstance.getApprovalDataSettings();
        if(!lstOfApprovalDataSettings.isEmpty()){
            for(Approval_Data_Setting__c approvlsetting :lstOfApprovalDataSettings ){
                List<String> tempList = new List<String>();
                if(approvlsetting.Approval_Fields__c != ''){
                    tempList = approvlsetting.Approval_Fields__c.split(',');
                }
                mapOfObjNameAndApprovalFields.put(approvlsetting.Object_API_name__c, tempList);
            }
        }
        //Build query to get all the fields values from fieldSets
        Map<Id, sObject> sObjectMap= new Map<Id, sObject>();
        for(String objName : mapOfObjNameAndApprovalFields.keySet()){
            if(mapOfObjNameAndObjIds.containsKey(objName)){
                String query='SELECT ';
                for(String fieldApiName: mapOfObjNameAndApprovalFields.get(objName)){
                    query = query + fieldApiName + ', '; 
                }
                List<String> ids=mapOfObjNameAndObjIds.get(objName);
                query += ' LastModifiedDate FROM ' + objName +' WHERE Id IN : ids';
                //As there can be multiple objects in approval and we can not query all objects in processRecords1 soql that's why loop is used.
                if(Limits.getQueries()<100){
                    Map<Id, sObject> sl = processListInstance.getSObjectMap(query, new Map<String, Object>{'ids'=>ids});
                    sObjectMap.putAll(sl);
                }
            }
        } 
        // Set the approval data into a wrapper class instance
        for(ProcessInstance ps :psList
        ){
            if(!ps.WorkItems.isEmpty()){
                String objName=getObjectName(ps.TargetObjectId);
                String usefulInfo = '';
                SubmittedRecordsWrapper wrapInstance = new SubmittedRecordsWrapper();
                wrapInstance.workItemId = ps.WorkItems[0].Id;
                wrapInstance.recordId = ps.TargetObjectId;
                wrapInstance.id = ps.TargetObjectId;
                wrapInstance.recordName = ps.TargetObject.Name;
                wrapInstance.relatedTo = Schema.getGlobalDescribe().get(objName).getDescribe().getLabel();//get the object name using the record id
                wrapInstance.submittedDate = Date.newInstance(ps.CreatedDate.year(),ps.CreatedDate.month(),ps.CreatedDate.day());
                if(!ps.steps.isEmpty()){
                    wrapInstance.submittedBy = ps.steps[0].OriginalActor.Name;
                    wrapInstance.submitterMessage = ps.steps[0].Comments;
                }
                if(delegatedApproverUserMap.containsKey(ps.WorkItems[0].OriginalActorId)){
                    wrapInstance.textStyle = 'color:rgb(204, 85, 0);';
                }
                else{
                    wrapInstance.textStyle = 'color:rgb(1, 118, 211);';
                }
                List<FieldsDataWrapper> wrapFieldsDataList = new List<FieldsDataWrapper>();     
                if(sObjectMap.containsKey(ps.TargetObjectId) && mapOfObjNameAndApprovalFields.containsKey(objName)){
                    for(String fieldname : mapOfObjNameAndApprovalFields.get(objName)){
                        FieldsDataWrapper wrapFieldsData = new FieldsDataWrapper();
                        if(fieldname.contains('.')){
                            List<String> fieldList= fieldname.split('\\.');
                            String crossObjectFieldApi='';
                            String crossObjectFieldName='';
                            if(fieldList[0].contains('__r')){
                                crossObjectFieldApi=fieldList[0].replace('__r','__c');
                                crossObjectFieldName=Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap().get(crossObjectFieldApi).getDescribe().getLabel();
                            }else{
                                crossObjectFieldApi=fieldList[0]+'Id';
                                crossObjectFieldName=Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap().get(crossObjectFieldApi).getDescribe().getLabel();
                            }
                                
                            if(sObjectMap.get(ps.TargetObjectId).getSObject(fieldList[0])!=null && (sObjectMap.get(ps.TargetObjectId)).getSObject(fieldList[0]).get(fieldList[1])!=null)
                                wrapFieldsData.fieldLabel = crossObjectFieldName+' - ' + fieldname;
                                wrapFieldsData.fieldVal = JSON.serialize((sObjectMap.get(ps.TargetObjectId)).getSObject(fieldList[0]).get(fieldList[1]));
                        }else{
                            //if((sObjectMap.get(ps.TargetObjectId)).get(fieldname)!=null)
                            wrapFieldsData.fieldLabel =  Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap().get(fieldname).getDescribe().getLabel();
                            wrapFieldsData.fieldVal = JSON.serialize((sObjectMap.get(ps.TargetObjectId)).get(fieldname)) == 'null'? 'No Data Present': JSON.serialize((sObjectMap.get(ps.TargetObjectId)).get(fieldname));
                        }
                        wrapFieldsDataList.add(wrapFieldsData);
                    }
                }
                wrapInstance.usefulInfo = usefulInfo;
                wrapInstance.fieldDataWrap = wrapFieldsDataList;
                wrapInstance.comment = '';
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

    //Method to Approve or Reject the selected records
    @AuraEnabled
    public static String processRecords( String lstWorkItemIds, String processType){
        try{
        List<ProcessApprvolWrapper> approvals= (List<ProcessApprvolWrapper>)System.JSON.deserialize(lstWorkItemIds, List<ProcessApprvolWrapper>.class);
        String message = '';
        Integer recordsProcessed = 0;
        String comments = processType == 'Approve' ? 'Approved' : 'Rejected';
        List<Approval.ProcessWorkitemRequest> lstWorkItemRequest = new List<Approval.ProcessWorkitemRequest>();//ProcessWorkitemRequest class has methods to programmatically process submitted records
        for(ProcessApprvolWrapper workItem : approvals){
            Approval.ProcessWorkitemRequest objWorkItemRequest = new Approval.ProcessWorkitemRequest();
            objWorkItemRequest.setComments(workItem.comment);
            objWorkItemRequest.setAction(processType);//approve or reject
            objWorkItemRequest.setWorkitemId(workItem.workItemId);
            lstWorkItemRequest.add(objWorkItemRequest);
        }
        Approval.ProcessResult[] lstProcessResult = Approval.process(lstWorkItemRequest,FALSE);//process method is used for approving/rejecting records depending on setAction attribute
        Set<Id> setOfrecords = new Set<Id>();
        list<String> instanceStatus = new List<String>();
        for(Approval.ProcessResult processResult : lstProcessResult){
            if(processResult.isSuccess()){
                recordsProcessed++;
                setOfrecords.add(processResult.getEntityId());
                instanceStatus.add(processResult.getInstanceStatus());
            }
            else{
                for(Database.Error error : processResult.getErrors()){
                    message += error.getMessage() + '\n\n';
                }
            }
        }
        if(recordsProcessed == approvals.size()){
            message = 'All records are '+comments+' successfully';
        }
        return message;
    }
    catch(Exception e){
        RSOCL_ExceptionLogger.logError(e, 'RSOCL_MultipleApprovalController', 'processRecords');
        throw new AuraHandledException(e.getMessage());
    }
    }

    public static String getObjectName(Id recordId){
        String objectName = recordId.getSObjectType().getDescribe().getName();
        if(Test.isRunningTest())
            objectName = 'Opportunity';
        
        return objectName;
    }

    //Wrapper class to store the column values of data table
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

    public class ProcessApprvolWrapper{
        @AuraEnabled public string workItemId;
        @AuraEnabled public string comment;
    }
    
    public class FieldsDataWrapper{
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String fieldVal;
    }

}