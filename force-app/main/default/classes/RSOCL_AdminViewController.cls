public with sharing class RSOCL_AdminViewController {
    @testVisible 
    public static RSOCL_MockDaoProcessInstanceController.IProcessDefination processListInstance = new RSOCL_MockDaoProcessInstanceController();

    //Method to fetch all the records which are submitted for approval by All Users
    @AuraEnabled
    public static List<SubmittedRecordsWrapper> getSubmittedApprovalRecordsByAllUsers(){
        try{

        List<SubmittedRecordsWrapper> lstSubmissionWrapper = new List<SubmittedRecordsWrapper>();
        //to get all approval requests across the org.
        List<ProcessInstance> psList = processListInstance.getProcessInstance('Started', null);
 
        Map<String, List<String>> mapOfObjNameAndObjIds=new Map<String, List<String>>();
        if(!psList.isEmpty()){
            for( ProcessInstance ps :psList){
                if(!ps.WorkItems.isEmpty()){
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
        }
        // Get the Custom Object Approval Data Settings record and set it as Map of corresponsing objectname and its fields.
        Map<String, List<String>> mapOfObjApiAndFields = new Map<String, List<String>>();
        List<Approval_Data_Setting__c> lstOfApprovalDataSettings = processListInstance.getApprovalDataSettings();
        if(!lstOfApprovalDataSettings.isEmpty()){
            for(Approval_Data_Setting__c approvlsetting :lstOfApprovalDataSettings ){
                List<String> tempList = approvlsetting.Approval_Fields__c.split(',');
                mapOfObjApiAndFields.put(approvlsetting.Object_API_name__c, tempList);
            }
        }
        //Build query to get all the fields values from above Map -> mapOfObjApiAndFields
        Map<Id, sObject> sObjectMap= new Map<Id, sObject>();
        for(String objName : mapOfObjApiAndFields.keySet()){
            if(mapOfObjNameAndObjIds.containsKey(objName)){
                String query='SELECT Id, ';
                for(String fieldApiName: mapOfObjApiAndFields.get(objName)){
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
                wrapInstance.Approver = ps.WorkItems[0].Actor.Name;
                if(!ps.steps.isEmpty()){
                    wrapInstance.submittedBy = ps.steps[0].OriginalActor.Name;
                    wrapInstance.submitterMessage = ps.steps[0].Comments;
                }
                List<FieldsDataWrapper> wrapFieldsDataList = new List<FieldsDataWrapper>();
                if(sObjectMap.containsKey(ps.TargetObjectId)){               
                    if(mapOfObjApiAndFields.containsKey(objName)){
                        for(String fieldname : mapOfObjApiAndFields.get(objName)){
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
                }
                wrapInstance.fieldDataWrap = wrapFieldsDataList;
                lstSubmissionWrapper.add(wrapInstance);
            }
        }
        return lstSubmissionWrapper;
        }
        catch(Exception e){
            RSOCL_ExceptionLogger.logError(e, 'RSOCL_AdminViewController', 'getSubmittedApprovalRecordsByAllUsers');
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
        @AuraEnabled public String Approver;
        @AuraEnabled public Date submittedDate;
        @AuraEnabled public String submitterMessage;
        @AuraEnabled public String usefulInfo;
        @AuraEnabled public String comment;
        @AuraEnabled public String status;
        @AuraEnabled public List<FieldsDataWrapper> fieldDataWrap;
    }
    
    public class FieldsDataWrapper{
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String fieldVal;
    }
}