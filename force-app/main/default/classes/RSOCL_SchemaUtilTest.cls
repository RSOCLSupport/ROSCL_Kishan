@IsTest
private class RSOCL_SchemaUtilTest {
  @IsTest
  static void testIsValidObject() {
    Assert.isTrue(
      RSOCL_SchemaUtil.isValidObject('Opportunity'),
      'Opportunity should be valid'
    );
    Assert.isFalse(
      RSOCL_SchemaUtil.isValidObject('Not_An_Object__c'),
      'Unknown object should be invalid'
    );
    Assert.isFalse(
      RSOCL_SchemaUtil.isValidObject(''),
      'Blank object should be invalid'
    );
  }

  @IsTest
  static void testValidFieldsKeepsRealFields() {
    List<String> valid = RSOCL_SchemaUtil.validFields(
      'Opportunity',
      'Amount, StageName,Account.Name,'
    );
    Assert.areEqual(
      new List<String>{ 'Amount', 'StageName', 'Account.Name' },
      valid,
      'Direct and relationship fields should be kept, trimmed'
    );
  }

  @IsTest
  static void testValidFieldsDropsInjectionAndUnknownNames() {
    List<String> valid = RSOCL_SchemaUtil.validFields(
      'Opportunity',
      new List<String>{
        'Name FROM User WHERE Id != null',
        'Not_A_Field__c',
        'Account.Not_A_Field__c',
        'Missing__r.Name',
        'Account.Owner.Name',
        'Amount'
      }
    );
    Assert.areEqual(
      new List<String>{ 'Amount' },
      valid,
      'Only the real field should be kept'
    );
  }

  @IsTest
  static void testValidFieldsForInvalidObjectOrNullList() {
    Assert.isTrue(
      RSOCL_SchemaUtil.validFields('Not_An_Object__c', 'Name').isEmpty(),
      'Fields of an unknown object should be dropped'
    );
    Assert.isTrue(
      RSOCL_SchemaUtil.validFields('Opportunity', (List<String>) null)
        .isEmpty(),
      'Null list should give an empty list'
    );
  }
}
