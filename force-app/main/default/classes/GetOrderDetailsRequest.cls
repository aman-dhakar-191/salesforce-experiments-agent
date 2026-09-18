@JsonAccess(
    serializable='always'
    deserializable='always'
)
global class GetOrderDetailsRequest {

    @InvocableVariable(
        label='Order Number'
        description='The order number to retrieve.'
        required=true
    )
    global String orderNumber;
}