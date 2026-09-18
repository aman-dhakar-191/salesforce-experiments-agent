public class GoogleDriveWebhookQueueable implements Queueable, Database.AllowsCallouts {

    private String channelId;
    private String resourceId;
    private String resourceState;
    private String messageNumber;

    public GoogleDriveWebhookQueueable(
        String channelId,
        String resourceId,
        String resourceState,
        String messageNumber
    ) {
        this.channelId = channelId;
        this.resourceId = resourceId;
        this.resourceState = resourceState;
        this.messageNumber = messageNumber;
    }

    public void execute(QueueableContext context) {

        System.debug('===== GOOGLE DRIVE QUEUEABLE STARTED =====');

        // ---------------------------------------------------------
        // Get current sync state
        // ---------------------------------------------------------

        List<Google_Drive_Sync_State__c> states = [
            SELECT Id, Last_Page_Token__c
            FROM Google_Drive_Sync_State__c
            WHERE Name = 'Google Drive'
            LIMIT 1
        ];

        System.debug(
            'SYNC STATE RECORD COUNT: ' +
            states.size()
        );

        if (states.isEmpty()) {
            System.debug(
                'NO SYNC STATE RECORD FOUND'
            );
            return;
        }

        Google_Drive_Sync_State__c state = states[0];

        String pageToken =
            state.Last_Page_Token__c;

        System.debug(
            'CURRENT PAGE TOKEN: ' +
            pageToken
        );

        // ---------------------------------------------------------
        // Query Google Drive changes
        // ---------------------------------------------------------

        HttpRequest req = new HttpRequest();

        req.setEndpoint(
            'callout:GoogleDrive/drive/v3/changes?pageToken=' +
            EncodingUtil.urlEncode(
                pageToken,
                'UTF-8'
            )
        );

        req.setMethod('GET');

        Http http = new Http();

        HttpResponse res = http.send(req);

        System.debug(
            '===== GOOGLE DRIVE CHANGES RESPONSE ====='
        );

        System.debug(
            'Status Code: ' +
            res.getStatusCode()
        );

        System.debug(
            'Response: ' +
            res.getBody()
        );

        if (res.getStatusCode() != 200) {
            throw new CalloutException(
                'Failed to get Google Drive changes: ' +
                res.getBody()
            );
        }

        // ---------------------------------------------------------
        // STEP 1: Detect / filter target Google Docs
        // ---------------------------------------------------------

        Map<String, Object> changesResponse =
            (Map<String, Object>) JSON.deserializeUntyped(
                res.getBody()
            );

        List<Object> changes =
            (List<Object>) changesResponse.get(
                'changes'
            );

        if (changes == null || changes.isEmpty()) {

            System.debug(
                'NO DRIVE CHANGES FOUND'
            );

            return;
        }

        System.debug(
            'TOTAL DRIVE CHANGES: ' +
            changes.size()
        );

        // ---------------------------------------------------------
        // Get Google Docs currently inside
        // our target Salesforce integration folder
        // ---------------------------------------------------------

        List<GoogleDriveNoteService.GoogleDriveFile> folderFiles =
            GoogleDriveNoteService.getDriveFiles();

        System.debug(
            'TARGET FOLDER GOOGLE DOC COUNT: ' +
            folderFiles.size()
        );

        // ---------------------------------------------------------
        // Create lookup of target folder files
        // ---------------------------------------------------------

        Map<String, GoogleDriveNoteService.GoogleDriveFile> targetFiles =
            new Map<String, GoogleDriveNoteService.GoogleDriveFile>();

        for (
            GoogleDriveNoteService.GoogleDriveFile file :
            folderFiles
        ) {

            targetFiles.put(
                file.id,
                file
            );
        }

        System.debug(
            'TARGET FILE IDS: ' +
            targetFiles.keySet()
        );

        // ---------------------------------------------------------
        // Find changed files belonging to target folder
        // ---------------------------------------------------------

        for (Object changeObj : changes) {

            Map<String, Object> change =
                (Map<String, Object>) changeObj;

            Boolean removed =
                change.containsKey('removed')
                ? (Boolean) change.get('removed')
                : false;

            if (removed) {

                System.debug(
                    'SKIPPING REMOVED FILE'
                );

                continue;
            }

            String fileId =
                (String) change.get('fileId');

            if (String.isBlank(fileId)) {

                System.debug(
                    'SKIPPING CHANGE WITHOUT FILE ID'
                );

                continue;
            }

            if (!targetFiles.containsKey(fileId)) {

                System.debug(
                    'SKIPPING FILE NOT IN TARGET FOLDER: ' +
                    fileId
                );

                continue;
            }

            GoogleDriveNoteService.GoogleDriveFile file =
                targetFiles.get(fileId);

            System.debug(
                '===== TARGET GOOGLE DOC DETECTED ====='
            );

            System.debug(
                'FILE ID: ' +
                file.id
            );

            System.debug(
                'FILE NAME: ' +
                file.name
            );

            System.debug(
                'MIME TYPE: ' +
                file.mimeType
            );

            System.debug(
                'FILE URL: ' +
                file.webViewLink
            );

            // ---------------------------------------------------------
            // STEP 2: Get Google Doc content
            // ---------------------------------------------------------

            String documentText =
                GoogleDocsService.getDocumentText(file.id);

            System.debug(
                '===== GOOGLE DOC TEXT RETRIEVED ====='
            );

            System.debug(
                'DOCUMENT TEXT: ' +
                documentText
            );
			// ---------------------------------------------------------
// STEP 3: Extract Lead data using AI
// ---------------------------------------------------------

LeadExtractionService.LeadData leadData =
    LeadExtractionService.extractLeadData(documentText);

System.debug(
    '===== LEAD DATA EXTRACTED ====='
);

System.debug(
    'FIRST NAME: ' +
    leadData.firstName
);

System.debug(
    'LAST NAME: ' +
    leadData.lastName
);

System.debug(
    'COMPANY: ' +
    leadData.company
);

System.debug(
    'EMAIL: ' +
    leadData.email
);

System.debug(
    'PHONE: ' +
    leadData.phone
);

System.debug(
    'DESCRIPTION: ' +
    leadData.description
);
        }

        System.debug(
            '===== STEP 1 DETECTION COMPLETE ====='
        );

        System.debug(
            '===== GOOGLE DRIVE QUEUEABLE FINISHED ====='
        );
    }
}