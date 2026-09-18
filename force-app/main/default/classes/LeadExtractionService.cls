public with sharing class LeadExtractionService {

    private static final String NAMED_CREDENTIAL = 'OpenRouter';

    private static final String MODEL =
        System.Label.OpenRouter_Lead_Extraction_Model;

    private static final String SYSTEM_PROMPT =
        System.Label.OpenRouter_Lead_Extraction_System_Prompt;


    public static LeadData extractLeadData(String meetingNotes) {

        if (String.isBlank(meetingNotes)) {
            throw new LeadExtractionException(
                'Meeting notes cannot be empty.'
            );
        }

        HttpRequest request = new HttpRequest();

        request.setEndpoint(
            'callout:' +
            NAMED_CREDENTIAL +
            '/api/v1/chat/completions'
        );

        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');

        request.setTimeout(120000);


        Map<String, Object> requestBody =
            new Map<String, Object>();

        requestBody.put('model', MODEL);
        requestBody.put(
            'reasoning',
            new Map<String, Object>{
                'enabled' => false
            }
        );


        List<Object> messages = new List<Object>();

        messages.add(
            new Map<String, Object>{
                'role' => 'system',
                'content' => SYSTEM_PROMPT
            }
        );

        messages.add(
            new Map<String, Object>{
                'role' => 'user',
                'content' => meetingNotes
            }
        );

        requestBody.put('messages', messages);


        /*
         * Force the model to return the Lead structure.
         */
        Map<String, Object> responseFormat =
            new Map<String, Object>();

        responseFormat.put(
            'type',
            'json_schema'
        );


        Map<String, Object> jsonSchema =
            new Map<String, Object>();

        jsonSchema.put(
            'name',
            'lead_extraction'
        );

        jsonSchema.put(
            'strict',
            true
        );


        Map<String, Object> schema =
            new Map<String, Object>();

        schema.put(
            'type',
            'object'
        );


        Map<String, Object> properties =
            new Map<String, Object>();


        properties.put(
            'firstName',
            new Map<String, Object>{
                'type' => new List<Object>{'string', 'null'}
            }
        );

        properties.put(
            'lastName',
            new Map<String, Object>{
                'type' => new List<Object>{'string', 'null'}
            }
        );

        properties.put(
            'company',
            new Map<String, Object>{
                'type' => new List<Object>{'string', 'null'}
            }
        );

        properties.put(
            'email',
            new Map<String, Object>{
                'type' => new List<Object>{'string', 'null'}
            }
        );

        properties.put(
            'phone',
            new Map<String, Object>{
                'type' => new List<Object>{'string', 'null'}
            }
        );

        properties.put(
            'description',
            new Map<String, Object>{
                'type' => new List<Object>{'string', 'null'}
            }
        );


        schema.put(
            'properties',
            properties
        );


        schema.put(
            'required',
            new List<Object>{
                'firstName',
                'lastName',
                'company',
                'email',
                'phone',
                'description'
            }
        );


        schema.put(
            'additionalProperties',
            false
        );


        jsonSchema.put(
            'schema',
            schema
        );

        responseFormat.put(
            'json_schema',
            jsonSchema
        );


        requestBody.put(
            'response_format',
            responseFormat
        );


        request.setBody(
            JSON.serialize(requestBody)
        );


        Http http = new Http();
        HttpResponse response = http.send(request);


        System.debug(
            'OpenRouter Status Code: ' +
            response.getStatusCode()
        );


        if (response.getStatusCode() < 200 ||
            response.getStatusCode() >= 300) {

            throw new LeadExtractionException(
                'OpenRouter API failed. Status: ' +
                response.getStatusCode() +
                ', Body: ' +
                response.getBody()
            );
        }


        Map<String, Object> responseBody =
            (Map<String, Object>)
                JSON.deserializeUntyped(
                    response.getBody()
                );


        if (responseBody == null ||
            !responseBody.containsKey('choices')) {

            throw new LeadExtractionException(
                'OpenRouter response does not contain choices.'
            );
        }


        List<Object> choices =
            (List<Object>) responseBody.get('choices');


        if (choices == null || choices.isEmpty()) {

            throw new LeadExtractionException(
                'OpenRouter returned no choices.'
            );
        }


        Map<String, Object> firstChoice =
            (Map<String, Object>) choices[0];


        Map<String, Object> message =
            (Map<String, Object>)
                firstChoice.get('message');


        if (message == null ||
            !message.containsKey('content')) {

            throw new LeadExtractionException(
                'OpenRouter response does not contain message content.'
            );
        }


        String content =
            (String) message.get('content');


        if (String.isBlank(content)) {

            throw new LeadExtractionException(
                'OpenRouter returned empty content.'
            );
        }


        LeadData leadData =
            (LeadData) JSON.deserialize(
                content,
                LeadData.class
            );


        if (leadData == null) {

            throw new LeadExtractionException(
                'Unable to parse Lead extraction response.'
            );
        }


        return leadData;
    }


    public class LeadData {

        public String firstName;
        public String lastName;
        public String company;
        public String email;
        public String phone;
        public String description;
    }


    public class LeadExtractionException extends Exception {
    }
}