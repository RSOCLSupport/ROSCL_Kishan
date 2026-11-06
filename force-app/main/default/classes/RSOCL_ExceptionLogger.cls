/**
 * @description Utility class to log exceptions in Exception_Logger__c
 */
public with sharing class RSOCL_ExceptionLogger {
  /**
   * @description Message shown to users; the technical details are only in Exception_Logger__c
   */
  public static final String USER_MESSAGE = 'Something went wrong. Please contact your Salesforce administrator.';

  /**
   * @description Builds the exception thrown to Lightning components without internal error details
   * @return AuraHandledException carrying USER_MESSAGE
   */
  public static AuraHandledException userFacingException() {
    AuraHandledException ex = new AuraHandledException(USER_MESSAGE);
    ex.setMessage(USER_MESSAGE);
    return ex;
  }

  /**
   * @description Creates an Exception_Logger__c record for the given exception
   * @param exceptions the exception to be logged
   * @param className name of the class where the error occurred
   * @param functionName name of the method where the error occurred
   */
  public static void logError(
    Exception exceptions,
    String className,
    String functionName
  ) {
    try {
      String errorMessage = exceptions.getMessage();
      String errorType = exceptions.getTypeName();
      Integer errorLineNumber = exceptions.getLineNumber();

      Exception_Logger__c error = new Exception_Logger__c(
        Class_Name__c = className,
        Function_Name__c = functionName,
        Error_Line_Number__c = errorLineNumber,
        Error_Message__c = errorMessage,
        Error_Type__c = errorType
      );

      Database.insert(error, AccessLevel.USER_MODE);
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'An error occurred while logging the error: ' + e.getMessage()
      );
    }
  }
}
