@IsTest
private class RSOCL_ExceptionLoggerTest {
  @IsTest
  static void testLogError() {
    // Create a mock exception for testing
    Exception mockException = new TestException('Test Exception');

    // Set up test data
    String className = 'TestClass';
    String functionName = 'testMethod';

    // logger inserts in USER_MODE, so the user needs the package permission set for FLS
    User runningUser = [
      SELECT Id
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    System.runAs(runningUser) {
      assignPackagePermissionSet(runningUser.Id);
    }

    Test.startTest();

    // Call the logError method
    System.runAs(runningUser) {
      RSOCL_ExceptionLogger.logError(mockException, className, functionName);
    }

    Test.stopTest();

    // Verify the error log record
    List<Exception_Logger__c> errorLogs = [
      SELECT
        Class_Name__c,
        Function_Name__c,
        Error_Line_Number__c,
        Error_Message__c,
        Error_Type__c
      FROM Exception_Logger__c
    ];

    System.assertEquals(1, errorLogs.size(), 'Error log record not created');

    Exception_Logger__c errorLog = errorLogs[0];

    System.assertEquals(
      className,
      errorLog.Class_Name__c,
      'Incorrect class name'
    );
    System.assertEquals(
      functionName,
      errorLog.Function_Name__c,
      'Incorrect function name'
    );
    System.assertEquals(
      mockException.getLineNumber(),
      errorLog.Error_Line_Number__c,
      'Incorrect error line number'
    );
    System.assertEquals(
      mockException.getMessage(),
      errorLog.Error_Message__c,
      'Incorrect error message'
    );
    System.assertEquals(
      mockException.getTypeName(),
      errorLog.Error_Type__c,
      'Incorrect error type'
    );
  }
  private static void assignPackagePermissionSet(Id userId) {
    PermissionSet ps = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Admin_Access_to_Mass_Approval_Product'
      LIMIT 1
    ];
    // the user may already have it in a subscriber org, and a duplicate assignment fails
    if (
      [
        SELECT COUNT()
        FROM PermissionSetAssignment
        WHERE AssigneeId = :userId AND PermissionSetId = :ps.Id
      ] == 0
    ) {
      insert new PermissionSetAssignment(
        AssigneeId = userId,
        PermissionSetId = ps.Id
      );
    }
  }

  private class TestException extends Exception {
  }
}
