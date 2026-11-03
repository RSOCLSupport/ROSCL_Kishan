@IsTest
private class RSOCL_ExceptionLoggerTest {

    @TestSetup
    static void setupTestData(){
        assignPackagePermissionSet(UserInfo.getUserId());
    }

    @IsTest
    static void testLogError() {
        User runningUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        System.runAs(runningUser) {
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
            
            Assert.areEqual(1, errorLogs.size(), 'Error log record not created');
            
            Exception_Logger__c errorLog = errorLogs[0];
            
            Assert.areEqual(className, errorLog.Class_Name__c, 'Incorrect class name');
            Assert.areEqual(functionName, errorLog.Function_Name__c, 'Incorrect function name');
            Assert.areEqual(mockException.getLineNumber(), errorLog.Error_Line_Number__c, 'Incorrect error line number');
            Assert.areEqual(mockException.getMessage(), errorLog.Error_Message__c, 'Incorrect error message');
            Assert.areEqual(mockException.getTypeName(), errorLog.Error_Type__c, 'Incorrect error type');
        }
    }

    private static void assignPackagePermissionSet(Id userId){
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Admin_Access_to_Mass_Approval_Product' LIMIT 1];
        List<PermissionSetAssignment> existingAssignments = [
            SELECT Id FROM PermissionSetAssignment 
            WHERE AssigneeId = :userId AND PermissionSetId = :ps.Id
        ];
        if(existingAssignments.isEmpty()){
            insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id);
        }
    }

    private class TestException extends Exception {}
}
