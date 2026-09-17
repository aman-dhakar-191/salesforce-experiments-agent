public with sharing class GoogleDocsService {

    private static final String NAMED_CREDENTIAL = 'GoogleDocs';

    public static String getDocumentText(String documentId) {

        if (String.isBlank(documentId)) {
            throw new GoogleDocsException(
                'Google Document ID is required.'
            );
        }

        HttpRequest request = new HttpRequest();

        request.setEndpoint(
            'callout:' +
            NAMED_CREDENTIAL +
            '/v1/documents/' +
            EncodingUtil.urlEncode(documentId, 'UTF-8')
        );

        request.setMethod('GET');

        Http http = new Http();
        HttpResponse response = http.send(request);

        System.debug(
            'Google Docs Status Code: ' +
            response.getStatusCode()
        );

        if (response.getStatusCode() != 200) {
            throw new GoogleDocsException(
                'Google Docs API failed. Status: ' +
                response.getStatusCode() +
                ', Body: ' +
                response.getBody()
            );
        }

        Map<String, Object> document =
            (Map<String, Object>) JSON.deserializeUntyped(
                response.getBody()
            );

        return extractPlainText(document);
    }

    private static String extractPlainText(
        Map<String, Object> document
    ) {

        if (document == null ||
            !document.containsKey('body')) {

            return '';
        }

        Map<String, Object> body =
            (Map<String, Object>) document.get('body');

        if (body == null ||
            !body.containsKey('content')) {

            return '';
        }

        List<Object> content =
            (List<Object>) body.get('content');

        String plainText = '';

        for (Object item : content) {

            Map<String, Object> structuralElement =
                (Map<String, Object>) item;

            if (!structuralElement.containsKey('paragraph')) {
                continue;
            }

            Map<String, Object> paragraph =
                (Map<String, Object>)
                    structuralElement.get('paragraph');

            if (!paragraph.containsKey('elements')) {
                continue;
            }

            List<Object> elements =
                (List<Object>) paragraph.get('elements');

            for (Object element : elements) {

                Map<String, Object> paragraphElement =
                    (Map<String, Object>) element;

                if (!paragraphElement.containsKey('textRun')) {
                    continue;
                }

                Map<String, Object> textRun =
                    (Map<String, Object>)
                        paragraphElement.get('textRun');

                if (textRun.containsKey('content')) {
                    plainText +=
                        (String) textRun.get('content');
                }
            }
        }

        return plainText;
    }

    public class GoogleDocsException extends Exception {
    }
}