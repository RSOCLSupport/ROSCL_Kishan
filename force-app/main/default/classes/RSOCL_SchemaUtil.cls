/**
 * @description Validates object and field API names against the org schema, so only names that
 * really exist are saved in Approval Data Settings or used in dynamic SOQL
 */
public with sharing class RSOCL_SchemaUtil {
  private static Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

  /**
   * @description Checks that the object exists in the org
   * @param objectName object api name
   * @return true when the object exists
   */
  public static Boolean isValidObject(String objectName) {
    return String.isNotBlank(objectName) &&
      globalDescribe.containsKey(objectName);
  }

  /**
   * @description Parses a comma-separated field list and keeps only fields that exist on the object
   * @param objectName object api name
   * @param commaSeparatedFields field api names, e.g. 'Amount,StageName,Account.Name,'
   * @return valid field api names, in the given order
   */
  public static List<String> validFields(
    String objectName,
    String commaSeparatedFields
  ) {
    List<String> fieldNames = new List<String>();
    if (String.isNotBlank(commaSeparatedFields)) {
      fieldNames = commaSeparatedFields.split(',');
    }
    return validFields(objectName, fieldNames);
  }

  /**
   * @description Keeps only fields that exist on the object: direct fields, or one-level
   * relationship fields such as Account.Name
   * @param objectName object api name
   * @param fieldNames field api names
   * @return valid field api names, trimmed, in the given order
   */
  public static List<String> validFields(
    String objectName,
    List<String> fieldNames
  ) {
    List<String> valid = new List<String>();
    if (!isValidObject(objectName) || fieldNames == null) {
      return valid;
    }
    Map<String, Schema.SObjectField> fieldMap = globalDescribe.get(objectName)
      .getDescribe()
      .fields.getMap();
    for (String fieldName : fieldNames) {
      if (
        String.isNotBlank(fieldName) && isValidField(fieldMap, fieldName.trim())
      ) {
        valid.add(fieldName.trim());
      }
    }
    return valid;
  }

  private static Boolean isValidField(
    Map<String, Schema.SObjectField> fieldMap,
    String fieldName
  ) {
    List<String> parts = fieldName.split('\\.');
    if (parts.size() == 1) {
      return fieldMap.containsKey(fieldName);
    }
    if (parts.size() != 2) {
      return false;
    }
    // same lookup naming the controllers use: Account -> AccountId, Custom__r -> Custom__c
    String lookupField = parts[0].endsWith('__r')
      ? parts[0].removeEnd('__r') + '__c'
      : parts[0] + 'Id';
    Schema.SObjectField lookup = fieldMap.get(lookupField);
    if (lookup == null) {
      return false;
    }
    List<Schema.SObjectType> targets = lookup.getDescribe().getReferenceTo();
    if (targets.isEmpty()) {
      return false;
    }
    // polymorphic lookups (e.g. Owner on Case) must have the field on every target
    for (Schema.SObjectType target : targets) {
      if (!target.getDescribe().fields.getMap().containsKey(parts[1])) {
        return false;
      }
    }
    return true;
  }
}
