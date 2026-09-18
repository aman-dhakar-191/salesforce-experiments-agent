global with sharing class GetOrderDetailsAction {

    @InvocableMethod(
        label='Get Order Details'
        description='Gets order details using the order number.'
    )
    global static List<GetOrderDetailsResponse> getOrderDetails(
        List<GetOrderDetailsRequest> requests
    ) {
        List<GetOrderDetailsResponse> results =
            new List<GetOrderDetailsResponse>();

        if (requests == null || requests.isEmpty()) {
            return results;
        }

        String orderNumber = requests[0].orderNumber;

        if (String.isBlank(orderNumber)) {
            return results;
        }

        List<Order> orders = [
            SELECT
                Id,
                OrderNumber,
                Status,
                EffectiveDate,
                TotalAmount,
                Account.Name
            FROM Order
            WHERE OrderNumber = :orderNumber
            LIMIT 1
        ];

        if (orders.isEmpty()) {
            return results;
        }

        Order ord = orders[0];

        GetOrderDetailsResponse response =
            new GetOrderDetailsResponse();

        response.orderNumber = ord.OrderNumber;
        response.status = ord.Status;
        response.effectiveDate = ord.EffectiveDate;
        response.totalAmount = ord.TotalAmount;

        if (ord.Account != null) {
            response.accountName = ord.Account.Name;
        }

        results.add(response);

        return results;
    }
}