@JsonAccess(
    serializable='always'
    deserializable='always'
)
global class GetOrderLineItem {

    @AuraEnabled
    global String productName;

    @AuraEnabled
    global String productCode;

    @AuraEnabled
    global Decimal quantity;

    @AuraEnabled
    global Decimal unitPrice;

    @AuraEnabled
    global Decimal totalPrice;
}