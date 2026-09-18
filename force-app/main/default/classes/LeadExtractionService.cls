public with sharing class LeadExtractionService {

    private static final String NAMED_CREDENTIAL = 'OpenRouter';

    private static final String MODEL =
        System.Label.OpenRouter_Lead_Extraction_Model;

    private static final String SYSTEM_PROMPT =
        System.Label.OpenRouter_Lead_Extraction_System_Prompt;

    /*
     * Maximum number of OpenRouter attempts.
     *
     * Attempt 1 = normal request
     * Attempt 2 = retry only when content is empty
     */
    private static final Integer MAX_ATTEMPTS = 2;


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


        // =============================================================
        // Build Request Body
        // =============================================================

        Map<String, Object> requestBody =
            new Map<String, Object>();

        requestBody.put(
            'model',
            MODEL
        );

        /*
         * Disable model reasoning to reduce unnecessary latency.
         */
        requestBody.put(
            'reasoning',
            new Map<String, Object>{
                'enabled' => false
            }
        );


        // =============================================================
        // Messages
        // =============================================================

        List<Object> messages =
            new List<Object>();

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

        requestBody.put(
            'messages',
            messages
        );


        // =============================================================
        // Structured JSON Response
        // =============================================================

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
                'type' => new List<Object>{
                    'string',
                    'null'
                }
            }
        );

        properties.put(
            'lastName',
            new Map<String, Object>{
                'type' => new List<Object>{
                    'string',
                    'null'
                }
            }
        );

        properties.put(
            'company',
            new Map<String, Object>{
                'type' => new List<Object>{
                    'string',
                    'null'
                }
            }
        );

        properties.put(
            'email',
            new Map<String, Object>{
                'type' => new List<Object>{
                    'string',
                    'null'
                }
            }
        );

        properties.put(
            'phone',
            new Map<String, Object>{
                'type' => new List<Object>{
                    'string',
                    'null'
                }
            }
        );

        properties.put(
            'description',
            new Map<String, Object>{
                'type' => new List<Object>{
                    'string',
                    'null'
                }
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


        // =============================================================
        // Call OpenRouter
        // Retry ONLY when content is empty
        // =============================================================

        Http http = new Http();

        HttpResponse response = null;

        String content = null;


        for (
            Integer attempt = 1;
            attempt <= MAX_ATTEMPTS;
            attempt++
        ) {

            System.debug(
                '===== OPENROUTER ATTEMPT ' +
                attempt +
                '/' +
                MAX_ATTEMPTS +
                ' ====='
            );


            response = http.send(request);


            System.debug(
                'OpenRouter Status Code: ' +
                response.getStatusCode()
            );

            System.debug(
                'OpenRouter Response Body: ' +
                response.getBody()
            );


            // =========================================================
            // HTTP ERROR
            // Do NOT retry HTTP errors for now.
            // =========================================================

            if (
                response.getStatusCode() < 200 ||
                response.getStatusCode() >= 300
            ) {

                throw new LeadExtractionException(
                    'OpenRouter API failed. Status: ' +
                    response.getStatusCode() +
                    ', Body: ' +
                    response.getBody()
                );
            }


            // =========================================================
            // Parse Response
            // =========================================================

            Map<String, Object> responseBody =
                (Map<String, Object>)
                    JSON.deserializeUntyped(
                        response.getBody()
                    );


            if (
                responseBody == null ||
                !responseBody.containsKey('choices')
            ) {

                throw new LeadExtractionException(
                    'OpenRouter response does not contain choices.'
                );
            }


            List<Object> choices =
                (List<Object>)
                    responseBody.get('choices');


            if (
                choices == null ||
                choices.isEmpty()
            ) {

                throw new LeadExtractionException(
                    'OpenRouter returned no choices.'
                );
            }


            Map<String, Object> firstChoice =
                (Map<String, Object>)
                    choices[0];


            Map<String, Object> message =
                (Map<String, Object>)
                    firstChoice.get('message');


            if (
                message == null ||
                !message.containsKey('content')
            ) {

                throw new LeadExtractionException(
                    'OpenRouter response does not contain message content.'
                );
            }


            content =
                (String)
                    message.get('content');


            // =========================================================
            // SUCCESS
            // =========================================================

            if (!String.isBlank(content)) {

                System.debug(
                    'OpenRouter returned valid content on attempt ' +
                    attempt
                );

                break;
            }


            // =========================================================
            // EMPTY CONTENT
            // Retry only once
            // =========================================================

            System.debug(
                'OpenRouter returned empty content on attempt ' +
                attempt
            );


            if (attempt < MAX_ATTEMPTS) {

                System.debug(
                    'Retrying OpenRouter because content is empty.'
                );

                continue;
            }


            throw new LeadExtractionException(
                'OpenRouter returned empty content after ' +
                MAX_ATTEMPTS +
                ' attempts.'
            );
        }


        // =============================================================
        // Final Content Validation
        // =============================================================

        if (String.isBlank(content)) {

            throw new LeadExtractionException(
                'OpenRouter returned empty content.'
            );
        }


        // =============================================================
        // Deserialize Lead Data
        // =============================================================

        LeadData leadData;

        try {

            leadData =
                (LeadData)
                    JSON.deserialize(
                        content,
                        LeadData.class
                    );

        } catch (Exception e) {

            throw new LeadExtractionException(
                'Unable to parse Lead extraction response: ' +
                e.getMessage()
            );
        }


        if (leadData == null) {

            throw new LeadExtractionException(
                'Unable to parse Lead extraction response.'
            );
        }


        return leadData;
    }


    // =============================================================
    // Lead Data
    // =============================================================

    public class LeadData {

        public String firstName;
        public String lastName;
        public String company;
        public String email;
        public String phone;
        public String description;
    }


    // =============================================================
    // Exception
    // =============================================================

    public class LeadExtractionException extends Exception {
    }
}