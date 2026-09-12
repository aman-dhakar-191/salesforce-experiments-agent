@JsonAccess(serializable='always' deserializable='always')
global class LeadCaptureResult {

    @AuraEnabled
    global Id leadId;

    @AuraEnabled
    global String leadName;

    @AuraEnabled
    global String message;

    @AuraEnabled
    global Boolean success;
}