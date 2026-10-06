public with sharing class RSOCL_ExceptionLogger {
    public static void logError(Exception exceptions, String className, String functionName) {
        try {           
            String errorMessage = exceptions.getMessage();
            String errorType = exceptions.getTypeName();
            Integer errorLineNumber = exceptions.getLineNumber();
            
            Exception_Logger__c error = new Exception_Logger__c(
                                                Class_Name__c = className, 
                                                Function_Name__c = functionName,
                                                Error_Line_Number__c = errorLineNumber, 
                                                Error_Message__c = errorMessage,
                                                Error_Type__c = errorType);

            insert error;
        } catch (Exception e) {
            System.debug('An error occurred while logging the error: ' + e.getMessage());
        }
    }
}