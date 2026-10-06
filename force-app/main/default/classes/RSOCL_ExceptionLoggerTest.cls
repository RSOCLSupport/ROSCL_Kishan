@isTest
private class RSOCL_ExceptionLoggerTest {
    
    @isTest
    static void testLogError() {
        // Create a mock exception for testing
        Exception mockException = new TestException('Test Exception');
        
        // Set up test data
        String className = 'TestClass';
        String functionName = 'testMethod';
        
        Test.startTest();
        
        // Call the logError method
        RSOCL_ExceptionLogger.logError(mockException, className, functionName);
        
        Test.stopTest();
        
        // Verify the error log record
        List<Exception_Logger__c> errorLogs = [
            SELECT Class_Name__c, Function_Name__c, Error_Line_Number__c,
                   Error_Message__c, Error_Type__c
            FROM Exception_Logger__c
        ];
        
        System.assertEquals(1, errorLogs.size(), 'Error log record not created');
        
        Exception_Logger__c errorLog = errorLogs[0];
        
        System.assertEquals(className, errorLog.Class_Name__c, 'Incorrect class name');
        System.assertEquals(functionName, errorLog.Function_Name__c, 'Incorrect function name');
        System.assertEquals(mockException.getLineNumber(), errorLog.Error_Line_Number__c, 'Incorrect error line number');
        System.assertEquals(mockException.getMessage(), errorLog.Error_Message__c, 'Incorrect error message');
        System.assertEquals(mockException.getTypeName(), errorLog.Error_Type__c, 'Incorrect error type');
    }

    
    private class TestException extends Exception {}
}