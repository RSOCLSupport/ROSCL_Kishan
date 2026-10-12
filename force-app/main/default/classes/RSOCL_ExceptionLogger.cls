/**
 * @description Utility class to log exceptions in Exception_Logger__c
 */
public with sharing class RSOCL_ExceptionLogger {
    /**
     * @description Creates an Exception_Logger__c record for the given exception
     * @param exceptions the exception to be logged
     * @param className name of the class where the error occurred
     * @param functionName name of the method where the error occurred
     */
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

           Database.insert(error, AccessLevel.USER_MODE);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'An error occurred while logging the error: ' + e.getMessage());
        }
    }
}