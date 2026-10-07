/**
 * @description Controller for the approval data setting screen
 */
public with sharing class RSOCL_ApprovalDataSettingController {

    /**
     * @description DAO instance, replaced with mock in test class
     */
    @TestVisible
    public static RSOCL_MockDaoProcessInstanceController.IProcessDefination processListInstance = new RSOCL_MockDaoProcessInstanceController();

    /**
     * @description Gets objects which have an active approval process
     * @return List of ObjectWrap
     */
    @AuraEnabled
    public static List<ObjectWrap> getObjects(){
        try{
            List<ObjectWrap> objWrapList = new List<ObjectWrap>();
            // active approval processes across the org
            List<ProcessDefinition> processList = processListInstance.getObjects('Active', 'Approval');
            if(processList.isEmpty()){
                return objWrapList;
            }
            Set<String> setOfObjNames = new Set<String>();
            for(ProcessDefinition pd : processList){
                setOfObjNames.add(pd.TableEnumOrId);
            }
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            for(String objApiName : setOfObjNames){
                objWrapList.add(buildObjectWrap(gd.get(objApiName)));
            }
            return objWrapList;
        }
        catch(Exception e){
            RSOCL_ExceptionLogger.logError(e, 'RSOCL_ApprovalDataSettingController', 'getObjects');
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets all fields of the given object
     * @param objectName object api name
     * @return List of FieldWrap
     */
    @AuraEnabled(cacheable=true)
    public static List<FieldWrap> getFields(String objectName){
        try{
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            Map<String, Schema.SObjectField> fmap = gd.get(objectName).getDescribe().fields.getMap();
            List<FieldWrap> strList = new List<FieldWrap>();
            for(String fieldName : fmap.keySet()){
                strList.add(buildFieldWrap(fieldName, fmap.get(fieldName)));
            }
            return strList;
        }
        catch(Exception e){
            RSOCL_ExceptionLogger.logError(e, 'RSOCL_ApprovalDataSettingController', 'getFields');
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Saves the approval data setting for an object if it does not exist already
     * @param objectName object api name
     * @param fieldList list of field api names
     * @return SaveResult with record id, name and status
     */
    @AuraEnabled
    public static SaveResult saveApproveSettings(String objectName, List<String> fieldList){
        try{
            List<Approval_Data_Setting__c> existingApprovalSetting = processListInstance.getApprovalDataSettings(objectName);
            if(!existingApprovalSetting.isEmpty()){
                SaveResult existing = new SaveResult();
                existing.recordId = existingApprovalSetting[0].Id;
                existing.status = 'Existing Record';
                existing.recordName = existingApprovalSetting[0].Name;
                return existing;
            }
            return insertSetting(objectName, fieldList);
        }
        catch(Exception e){
            RSOCL_ExceptionLogger.logError(e, 'RSOCL_ApprovalDataSettingController', 'saveApproveSettings');
            throw new AuraHandledException(e.getMessage());
        }
    }

    // describe is costly, so it is kept out of the loop in getObjects
    private static ObjectWrap buildObjectWrap(Schema.SObjectType sobjType){
        Schema.DescribeSObjectResult r = sobjType.getDescribe();
        ObjectWrap objWrap = new ObjectWrap();
        objWrap.objLabel = r.getLabel();
        objWrap.objName = r.getName();
        return objWrap;
    }

    private static FieldWrap buildFieldWrap(String fieldName, Schema.SObjectField field){
        FieldWrap fieldWrap = new FieldWrap();
        fieldWrap.fieldName = fieldName;
        fieldWrap.fieldLabel = field.getDescribe().getLabel();
        return fieldWrap;
    }

    // creates the new setting record and prepares the result
    private static SaveResult insertSetting(String objectName, List<String> fieldList){
        SaveResult result = new SaveResult();
        String fieldsValue = '';
        for(String fieldApiName : fieldList){
            fieldsValue += fieldApiName + ',';
        }
        Approval_Data_Setting__c approvalSetting = new Approval_Data_Setting__c();
        approvalSetting.Object_API_name__c = objectName;
        approvalSetting.Approval_Fields__c = fieldsValue;

        Database.SaveResult[] srList = Database.insert(new List<Approval_Data_Setting__c>{approvalSetting}, false, AccessLevel.USER_MODE);
        Database.SaveResult sr = srList[0];
        if(sr.isSuccess() && sr.getId() != null){
            System.debug(LoggingLevel.DEBUG, 'Successfully inserted Approval Data Setting. ' + sr.getId());
            result.recordId = sr.getId();
            result.status = 'SUCCESS';
            Approval_Data_Setting__c successRec = [SELECT Name FROM Approval_Data_Setting__c WHERE Id = :sr.getId() WITH USER_MODE];
            result.recordName = successRec.Name;
        }else if(!sr.isSuccess()){
            for(Database.Error err : sr.getErrors()){
                System.debug(LoggingLevel.ERROR, err.getStatusCode() + ': ' + err.getMessage());
            }
            result.status = 'FAILED';
            result.recordId = '';
            result.recordName = '';
        }
        return result;
    }

    /**
     * @description Wrapper for object name and label
     */
    public class ObjectWrap{
        /**
         * @description object api name
         */
        @AuraEnabled
        public String objName{get;set;}
        /**
         * @description object label
         */
        @AuraEnabled
        public String objLabel{get;set;}
    }

    /**
     * @description Wrapper for field name and label
     */
    public class FieldWrap{
        /**
         * @description field api name
         */
        @AuraEnabled
        public String fieldName{get;set;}
        /**
         * @description field label
         */
        @AuraEnabled
        public String fieldLabel{get;set;}
    }

    /**
     * @description Result of the save operation
     */
    public class SaveResult{
        /**
         * @description id of the saved record
         */
        @AuraEnabled
        public String recordId;
        /**
         * @description SUCCESS, FAILED or Existing Record
         */
        @AuraEnabled
        public String status;
        /**
         * @description name of the saved record
         */
        @AuraEnabled
        public String recordName;
    }
}