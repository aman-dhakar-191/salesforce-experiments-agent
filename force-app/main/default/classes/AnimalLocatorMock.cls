public class AnimalLocatorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"animal":{"id":1,"name":"chicken","says":"cluck"}}');
            response.setStatusCode(200);
            return response;
        }
    }