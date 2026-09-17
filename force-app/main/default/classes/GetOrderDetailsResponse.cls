@JsonAccess(
    serializable='always'
    deserializable='always'
)
global class GetOrderDetailsResponse {

    @InvocableVariable(
        label='Order Number'
        description='The unique order number.'
    )
    @AuraEnabled
    global String orderNumber;

    @InvocableVariable(
        label='Status'
        description='The current status of the order.'
    )
    @AuraEnabled
    global String status;

    @InvocableVariable(
        label='Effective Date'
        description='The date on which the order becomes effective.'
    )
    @AuraEnabled
    global Date effectiveDate;

    @InvocableVariable(
        label='Total Amount'
        description='The total monetary amount of the order.'
    )
    @AuraEnabled
    global Decimal totalAmount;

    @InvocableVariable(
        label='Account Name'
        description='The name of the account associated with the order.'
    )
    @AuraEnabled
    global String accountName;

    @InvocableVariable(
        label='Line Items'
        description='The list of products and quantities included in the order.'
    )
    @AuraEnabled
    global List<GetOrderLineItem> lineItems;
}