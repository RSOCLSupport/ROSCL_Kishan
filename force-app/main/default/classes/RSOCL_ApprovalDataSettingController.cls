public with sharing class RSOCL_ApprovalDataSettingController {

    @testVisible 
    public static RSOCL_MockDaoProcessInstanceController.IProcessDefination processListInstance = new RSOCL_MockDaoProcessInstanceController();
    
    @Auraenabled
    public static List<ObjectWrap> getObjects()
    {
        try{
        List<ObjectWrap> objWrapList = new List<ObjectWrap>();
        // Get Active approval processes across the org
        List<ProcessDefinition> processList = processListInstance.getObjects('Active', 'Approval');

        if(processList.isEmpty()){
            return objWrapList;
        }
        Set<String> setofOBjNames = new Set<String>(); 
        if(!processList.isEmpty()){
            for(ProcessDefinition pd : processList ){
                setofOBjNames.add(pd.TableEnumOrId);
            }
        }
        map <String,Schema.SObjectType> gd = Schema.getGlobalDescribe();
        for( String objapiname : setofOBjNames){
            ObjectWrap objwrap = new ObjectWrap();
            Schema.SObjectType sobjType = gd.get(objapiname);
            Schema.DescribeSObjectResult r = sobjType.getDescribe();
            objwrap.objLabel = r.getLabel();
            objwrap.objName = r.getName();
            objWrapList.add(objwrap);
        }
        return objWrapList;
    }
    catch(Exception e){
        RSOCL_ExceptionLogger.logError(e, 'RSOCL_ApprovalDataSettingController', 'getObjects');
        throw new AuraHandledException(e.getMessage());
    }
    }

    @Auraenabled(cacheable=true)
    public static List<FieldWrap> getFields(string objectName)
    {
        try{
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe(); 
        Schema.SObjectType ctype = gd.get(objectName); 
        Map<String, Schema.SobjectField> fmap = ctype.getDescribe().fields.getMap();   
        List<FieldWrap> strList = new List<FieldWrap>();
        for(String fieldName: fmap.keySet()) {
            FieldWrap wmp = new FieldWrap();
            wmp.fieldName = fieldName;
            wmp.fieldLabel = fmap.get(fieldName).getDescribe().getLabel();        
            strList.add(wmp);
        }
        return strList;
    }
    catch(Exception e){
        RSOCL_ExceptionLogger.logError(e, 'RSOCL_ApprovalDataSettingController', 'getFields');
        throw new AuraHandledException(e.getMessage());
    }
    }

    @Auraenabled
    public static SaveResult saveApproveSettings(String objectName, List<String>fieldList){
        try{
        SaveResult result = new SaveResult();
        Set<Id> successIds = new Set<Id>();
        List<Approval_Data_Setting__c>  existingApprovalSetting = processListInstance.getApprovalDataSettings(objectName);
        if (existingApprovalSetting.size() > 0 ) {
            result.recordId = existingApprovalSetting[0].Id;
            result.status = 'Existing Record';
            result.recordName = existingApprovalSetting[0].Name;
        }
        else{
            List<Approval_Data_Setting__c> approvalSettingsList = new  List<Approval_Data_Setting__c>();
            Approval_Data_Setting__c approvalsetting = new Approval_Data_Setting__c();
            approvalsetting.Object_API_name__c = objectName;
            String mystring = '';
            for(String sss : fieldList){
                mystring += sss + ',' ;
            }
            approvalsetting.Approval_Fields__c = mystring;
            approvalSettingsList.add(approvalsetting);

            Database.SaveResult[] srList = Database.insert(approvalSettingsList, false);
            // Iterate through each returned result
           
            for (Database.SaveResult sr : srList) {
                if (sr.isSuccess()) {
                    // Operation was successful, so get the ID of the record that was processed
                    System.debug('Successfully inserted Approval Data Setting. ' + sr.getId());
                    if(sr.getId()!= null){
                        result.recordId = sr.getId();
                        result.status = 'SUCCESS';
                       // result.recordName = '';
                        successIds.add(sr.getId());
                    }
                }
                else {
                    // Operation failed, so get all errors                
                    for(Database.Error err : sr.getErrors()) {
                        System.debug('The following error has occurred.');                    
                        System.debug(err.getStatusCode() + ': ' + err.getMessage());
                        result.status = 'FAILED';
                        result.recordId = '';
                        result.recordName = '';
                    }
                }
            }
        }
        if(result.status == 'SUCCESS' && !successIds.isEmpty() ){
            Approval_Data_Setting__c successRec = [SELECT  Name FROM Approval_Data_Setting__c WHERE Id IN:successIds  ];
            result.recordName = successRec.Name;
        }
        return result;
    }
    catch(Exception e){
        RSOCL_ExceptionLogger.logError(e, 'RSOCL_ApprovalDataSettingController', 'saveApproveSettings');
        throw new AuraHandledException(e.getMessage());
    }
    }

    public class ObjectWrap
    {
        @Auraenabled
        public string objName{get;set;}
        @Auraenabled
        public string objLabel{get;set;}
    }

    public class FieldWrap
    {
        @Auraenabled
        public string fieldName{get;set;}
        @Auraenabled
        public string fieldLabel{get;set;}
    }

    public class SaveResult 
    {
        @Auraenabled
        public string recordId;
        @Auraenabled
        public string status;
        @Auraenabled
        public string recordName;

    }

}