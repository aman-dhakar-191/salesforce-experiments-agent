@isTest
global class ParkServiceMock implements WebServiceMock {
    global void doInvoke(
        Object stub,
        Object request,
        Map<String, Object> response,
        String endpoint,
        String soapAction,
        String requestName,
        String responseNS,
        String responseName,
        String responseType) {

        // Build a fake response matching the byCountryResponse type
        ParkService.byCountryResponse respElement = new ParkService.byCountryResponse();
        respElement.return_x = new List<String>{ 'Park1', 'Park2', 'Park3' };
        response.put('response_x', respElement);
    }
}