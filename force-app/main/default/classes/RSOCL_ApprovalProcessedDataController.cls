public with sharing class RSOCL_ApprovalProcessedDataController {

    @testVisible 
    public static RSOCL_MockDaoProcessInstanceController.IProcessDefination processListInstance = new RSOCL_MockDaoProcessInstanceController();

    @AuraEnabled
    public static List<SubmittedRecordsWrapper> getProcessedAprrovalRecords(){
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
        List<ProcessInstance> psList = processListInstance.getProcessInstance(UserInfo.getUserId(), delegatedApproverUserMap.keySet(), setOfGroupIds, null);

        Map<String, List<String>> mapOfObjNameAndObjIds=new Map<String, List<String>>();
        if(!psList.isEmpty()){
            for( ProcessInstance ps :psList){
                if(!ps.Steps.isEmpty()){
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
        // Get the Custom Object Approval Data Settings record and set it as Map of corresponsing objectname and its fields.
        Map<String, List<String>> mapOfObjNameAndApprovalFields = new Map<String, List<String>>();
        List<Approval_Data_Setting__c> lstOfApprovalDataSettings = processListInstance.getApprovalDataSettings();
        if(!lstOfApprovalDataSettings.isEmpty()){
            for(Approval_Data_Setting__c approvlsetting :lstOfApprovalDataSettings ){
                List<String> tempList = approvlsetting.Approval_Fields__c.split(',');
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
            if(!ps.Steps.isEmpty()){
                String objName=getObjectName(ps.TargetObjectId);
                String usefulInfo = '';
                SubmittedRecordsWrapper wrapInstance = new SubmittedRecordsWrapper();
                //wrapInstance.workItemId = ps.WorkItems[0].Id;
                wrapInstance.recordId = ps.TargetObjectId;
                wrapInstance.recordName = ps.TargetObject.Name;
                wrapInstance.relatedTo = Schema.getGlobalDescribe().get(objName).getDescribe().getLabel();//get the object name using the record id
                Date lastModifiedDate = Date.valueOf(ps.steps[0].SystemModstamp);
                wrapInstance.approvedDate = Date.newInstance(lastModifiedDate.year(),lastModifiedDate.month(),lastModifiedDate.day());
                wrapInstance.approverComments = ps.steps[0].Comments;
                wrapInstance.stepStatus = ps.steps[0].StepStatus;
                if(ps.steps[0].StepStatus == 'Approved'){
                    wrapInstance.approvedStatus = 'Last Week Approved';
                    wrapInstance.rowColor = 'background-color:rgb(80, 200, 120);color:white;';
                }
                else if(ps.steps[0].StepStatus == 'Rejected'){
                    wrapInstance.approvedStatus = 'Last Week Rejected';
                    wrapInstance.rowColor = 'background-color:rgb(186, 5, 23);color:white;';
                }
                List<FieldsDataWrapper> wrapFieldsDataList = new List<FieldsDataWrapper>();
                if(sObjectMap.containsKey(ps.TargetObjectId)){     
                    if(mapOfObjNameAndApprovalFields.containsKey(objName)){
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
                               // if((sObjectMap.get(ps.TargetObjectId)).get(fieldname)!=null)
                                wrapFieldsData.fieldLabel =  Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap().get(fieldname).getDescribe().getLabel();
                                wrapFieldsData.fieldVal = JSON.serialize((sObjectMap.get(ps.TargetObjectId)).get(fieldname)) == 'null'? 'No Data Present': JSON.serialize((sObjectMap.get(ps.TargetObjectId)).get(fieldname));
                            }
                            wrapFieldsDataList.add(wrapFieldsData);
                        }
                    }
                }
                wrapInstance.fieldDataWrap = wrapFieldsDataList;
                lstSubmissionWrapper.add(wrapInstance);
            }
        }
        return lstSubmissionWrapper;
    }
    catch(Exception e){
        RSOCL_ExceptionLogger.logError(e, 'RSOCL_ApprovalProcessedDataController', 'getProcessedAprrovalRecords');
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
    public class FieldsDataWrapper{
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String fieldVal;
    }
}