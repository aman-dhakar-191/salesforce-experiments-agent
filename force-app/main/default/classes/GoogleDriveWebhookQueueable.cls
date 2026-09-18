public class GoogleDriveWebhookQueueable
    implements Queueable, Database.AllowsCallouts {

    private String channelId;
    private String resourceId;
    private String resourceState;
    private String messageNumber;

    /*
     * Used when processing additional pages from Google Drive.
     *
     * null = start from Salesforce sync state.
     * non-null = continue from a Google Drive nextPageToken.
     */
    private String processingPageToken;


    public GoogleDriveWebhookQueueable(
        String channelId,
        String resourceId,
        String resourceState,
        String messageNumber
    ) {
        this(
            channelId,
            resourceId,
            resourceState,
            messageNumber,
            null
        );
    }


    public GoogleDriveWebhookQueueable(
        String channelId,
        String resourceId,
        String resourceState,
        String messageNumber,
        String processingPageToken
    ) {
        this.channelId = channelId;
        this.resourceId = resourceId;
        this.resourceState = resourceState;
        this.messageNumber = messageNumber;
        this.processingPageToken = processingPageToken;
    }


    public void execute(QueueableContext context) {

        System.debug(
            '===== GOOGLE DRIVE QUEUEABLE STARTED ====='
        );

        System.debug(
            'CHANNEL ID: ' +
            channelId
        );

        System.debug(
            'RESOURCE ID: ' +
            resourceId
        );

        System.debug(
            'RESOURCE STATE: ' +
            resourceState
        );

        System.debug(
            'MESSAGE NUMBER: ' +
            messageNumber
        );


        // =========================================================
        // STEP 1: Get Salesforce Sync State
        // =========================================================

        List<Google_Drive_Sync_State__c> states = [
            SELECT Id,
                   Last_Page_Token__c
            FROM Google_Drive_Sync_State__c
            WHERE Name = 'Google Drive'
            LIMIT 1
            FOR UPDATE
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


        Google_Drive_Sync_State__c state =
            states[0];


        String pageToken;


        if (String.isBlank(processingPageToken)) {

            pageToken =
                state.Last_Page_Token__c;

            System.debug(
                'USING SYNC STATE PAGE TOKEN: ' +
                pageToken
            );

        } else {

            pageToken =
                processingPageToken;

            System.debug(
                'USING CHAINED PAGE TOKEN: ' +
                pageToken
            );
        }


        if (String.isBlank(pageToken)) {

            System.debug(
                'PAGE TOKEN IS EMPTY'
            );

            return;
        }


        // =========================================================
        // STEP 2: Get Google Drive Changes
        // =========================================================

        HttpRequest req =
            new HttpRequest();


        req.setEndpoint(
            'callout:GoogleDrive/drive/v3/changes' +
            '?pageToken=' +
            EncodingUtil.urlEncode(
                pageToken,
                'UTF-8'
            ) +
            '&pageSize=100' +
            '&fields=changes(fileId,removed),' +
            'nextPageToken,newStartPageToken'
        );


        req.setMethod('GET');


        Http http =
            new Http();


        HttpResponse res =
            http.send(req);


        System.debug(
            '===== GOOGLE DRIVE CHANGES RESPONSE ====='
        );

        System.debug(
            'STATUS CODE: ' +
            res.getStatusCode()
        );

        System.debug(
            'RESPONSE: ' +
            res.getBody()
        );


        if (res.getStatusCode() != 200) {

            throw new CalloutException(
                'Failed to get Google Drive changes: ' +
                res.getBody()
            );
        }


        Map<String, Object> changesResponse =
            (Map<String, Object>)
                JSON.deserializeUntyped(
                    res.getBody()
                );


        List<Object> changes =
            (List<Object>)
                changesResponse.get(
                    'changes'
                );


        String nextPageToken =
            (String)
                changesResponse.get(
                    'nextPageToken'
                );


        String newStartPageToken =
            (String)
                changesResponse.get(
                    'newStartPageToken'
                );


        System.debug(
            'CURRENT PAGE TOKEN: ' +
            pageToken
        );

        System.debug(
            'NEXT PAGE TOKEN: ' +
            nextPageToken
        );

        System.debug(
            'NEW START PAGE TOKEN: ' +
            newStartPageToken
        );


        if (changes == null) {

            changes =
                new List<Object>();
        }


        System.debug(
            'TOTAL DRIVE CHANGES: ' +
            changes.size()
        );


        // =========================================================
        // STEP 3: Get Google Docs in Target Folder
        // =========================================================

        List<GoogleDriveNoteService.GoogleDriveFile> folderFiles =
            GoogleDriveNoteService.getDriveFiles();


        System.debug(
            'TARGET FOLDER GOOGLE DOC COUNT: ' +
            folderFiles.size()
        );


        Map<String, GoogleDriveNoteService.GoogleDriveFile>
            targetFiles =
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


        // =========================================================
        // STEP 4: Get Salesforce File Tracking Records
        // =========================================================

        Map<String, Google_Drive_File__c>
            trackingRecords =
                new Map<String, Google_Drive_File__c>();


        if (!targetFiles.isEmpty()) {

            for (
                Google_Drive_File__c record :
                [
                    SELECT Id,
						Google_File_Id__c,
						Processed__c,
						Processing_Status__c,
						Lead__c,
						Last_Processed_Date__c,
						Processing_Error__c
					FROM Google_Drive_File__c
					WHERE Google_File_Id__c IN :targetFiles.keySet()
					WITH SYSTEM_MODE
                ]
            ) {

                trackingRecords.put(
                    record.Google_File_Id__c,
                    record
                );
            }
        }


        System.debug(
            'TRACKING RECORD COUNT: ' +
            trackingRecords.size()
        );


        // =========================================================
        // STEP 5: Prepare ALL Callout Results
        // =========================================================

        /*
         * IMPORTANT:
         *
         * No Salesforce DML is performed inside this loop.
         *
         * Google Docs callouts and OpenRouter callouts happen first.
         * Leads are only inserted AFTER this loop finishes.
         */

        List<Lead> leadsToInsert =
            new List<Lead>();


        /*
         * Maps Google File ID -> Lead object.
         *
         * After Lead insertion, Salesforce assigns the Lead Id.
         */
        Map<String, Lead> leadsByFileId =
            new Map<String, Lead>();


        /*
         * Tracking records are prepared in memory.
         */
        List<Google_Drive_File__c>
            trackingRecordsToSave =
                new List<Google_Drive_File__c>();


        /*
         * Keeps track of files processed during THIS transaction.
         *
         * Google can send multiple change notifications for the
         * same document while it is being edited.
         */
        Set<String> processedFileIdsThisTransaction =
            new Set<String>();


        // =========================================================
        // STEP 6: Process Changed Google Docs
        // =========================================================

        for (Object changeObj : changes) {

            Map<String, Object> change =
                (Map<String, Object>)
                    changeObj;


            // -----------------------------------------------------
            // Check whether the file was removed
            // -----------------------------------------------------

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


            // -----------------------------------------------------
            // Get changed file ID
            // -----------------------------------------------------

            String fileId =
                (String)
                    change.get(
                        'fileId'
                    );


            if (String.isBlank(fileId)) {

                System.debug(
                    'SKIPPING CHANGE WITHOUT FILE ID'
                );

                continue;
            }


            // -----------------------------------------------------
            // Make sure file belongs to target folder
            // -----------------------------------------------------

            if (!targetFiles.containsKey(fileId)) {

                System.debug(
                    'SKIPPING FILE NOT IN TARGET FOLDER: ' +
                    fileId
                );

                continue;
            }


            // -----------------------------------------------------
            // Prevent duplicate processing in same transaction
            // -----------------------------------------------------

            if (
                processedFileIdsThisTransaction
                    .contains(fileId)
            ) {

                System.debug(
                    'SKIPPING DUPLICATE CHANGE IN SAME TRANSACTION: ' +
                    fileId
                );

                continue;
            }


            // -----------------------------------------------------
            // Get Salesforce tracking record
            // -----------------------------------------------------

            Google_Drive_File__c trackingRecord =
                trackingRecords.get(
                    fileId
                );


            // -----------------------------------------------------
// Skip files that already have a Salesforce tracking record
// -----------------------------------------------------

if (trackingRecord != null) {

    System.debug(
        'SKIPPING EXISTING TRACKING RECORD: ' +
        fileId
    );

    processedFileIdsThisTransaction.add(
        fileId
    );

    continue;
}


            GoogleDriveNoteService.GoogleDriveFile file =
                targetFiles.get(
                    fileId
                );


            System.debug(
                '================================================='
            );

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


            // =====================================================
            // STEP 6A: Get Google Docs Content
            // =====================================================

            System.debug(
                '===== GETTING GOOGLE DOC CONTENT ====='
            );


            String documentText =
                GoogleDocsService.getDocumentText(
                    file.id
                );


            System.debug(
                'GOOGLE DOC TEXT LENGTH: ' +
                (
                    documentText == null
                    ? 0
                    : documentText.length()
                )
            );


            if (String.isBlank(documentText)) {

                throw new CalloutException(
                    'Google document contains no text. ' +
                    'File ID: ' +
                    file.id
                );
            }


            // =====================================================
            // STEP 6B: Extract Lead Data Using AI
            // =====================================================

            System.debug(
                '===== EXTRACTING LEAD DATA USING AI ====='
            );


            LeadExtractionService.LeadData leadData =
                LeadExtractionService.extractLeadData(
                    documentText
                );


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


            // =====================================================
            // STEP 6C: BUILD Lead — NO DML
            // =====================================================

            System.debug(
                '===== BUILDING SALESFORCE LEAD ====='
            );


            Lead newLead =
                LeadCreationService.buildLead(
                    leadData
                );


            /*
             * IMPORTANT:
             *
             * buildLead() only creates the Lead object.
             * It does NOT perform insert.
             */
            leadsToInsert.add(
                newLead
            );


            leadsByFileId.put(
                fileId,
                newLead
            );


            // =====================================================
            // STEP 6D: Prepare Tracking Record — NO DML
            // =====================================================

            if (trackingRecord == null) {

                trackingRecord =
                    new Google_Drive_File__c();

                trackingRecord.Google_File_Id__c =
                    file.id;

                trackingRecord.File_Name__c =
                    file.name;

                trackingRecord.File_Type__c =
                    'Google Doc';

                trackingRecord.File_URL__c =
                    file.webViewLink;

                trackingRecord.Mime_Type__c =
                    file.mimeType;

                trackingRecord.Google_Created_Date__c =
                    parseDateTime(
                        file.createdTime
                    );

                trackingRecord.Google_Modified_Date__c =
                    parseDateTime(
                        file.modifiedTime
                    );
            }


            trackingRecord.Processed__c =
                true;

            trackingRecord.Processing_Status__c =
                'Processed';

            trackingRecord.Processing_Error__c =
                null;

            /*
             * Lead__c cannot be assigned yet because
             * the Lead has not been inserted.
             *
             * We assign Lead__c after insert below.
             */

            trackingRecord.Last_Processed_Date__c =
                System.now();


            trackingRecordsToSave.add(
                trackingRecord
            );


            processedFileIdsThisTransaction.add(
                fileId
            );


            System.debug(
                '===== GOOGLE DRIVE FILE PREPARED ====='
            );

            System.debug(
                'GOOGLE FILE ID: ' +
                fileId
            );
        }


        // =========================================================
        // STEP 7: INSERT ALL LEADS
        // =========================================================

        /*
         * At this point ALL Google Docs and OpenRouter callouts
         * are finished.
         *
         * Therefore it is now safe to perform DML.
         */

        if (!leadsToInsert.isEmpty()) {

            System.debug(
                '===== INSERTING SALESFORCE LEADS ====='
            );

            System.debug(
                'LEADS TO INSERT: ' +
                leadsToInsert.size()
            );


            insert as system leadsToInsert;


            System.debug(
                '===== SALESFORCE LEADS CREATED ====='
            );


            for (Lead lead : leadsToInsert) {

                System.debug(
                    'CREATED LEAD ID: ' +
                    lead.Id
                );
            }
        }


        // =========================================================
        // STEP 8: Assign Lead IDs to Tracking Records
        // =========================================================

        for (
            String fileId :
            leadsByFileId.keySet()
        ) {

            Lead newLead =
                leadsByFileId.get(
                    fileId
                );


            Google_Drive_File__c trackingRecord =
                null;


            /*
             * Find the prepared tracking record
             * belonging to this Google file.
             */
            for (
                Google_Drive_File__c record :
                trackingRecordsToSave
            ) {

                if (
                    record.Google_File_Id__c ==
                    fileId
                ) {

                    trackingRecord =
                        record;

                    break;
                }
            }


            if (trackingRecord != null) {

                trackingRecord.Lead__c =
                    newLead.Id;

                System.debug(
                    'TRACKING RECORD LEAD ASSIGNED: ' +
                    newLead.Id
                );
            }
        }


        // =========================================================
        // STEP 9: Save File Processing Results
        // =========================================================

        if (
            !trackingRecordsToSave.isEmpty()
        ) {

            System.debug(
                '===== UPDATING GOOGLE DRIVE TRACKING RECORDS ====='
            );


            upsert as system trackingRecordsToSave;


            System.debug(
                'TRACKING RECORDS UPDATED: ' +
                trackingRecordsToSave.size()
            );
        }


        // =========================================================
        // STEP 10: Handle Additional Google Drive Pages
        // =========================================================

        if (!String.isBlank(nextPageToken)) {

            System.debug(
                '===== MORE GOOGLE DRIVE CHANGES AVAILABLE ====='
            );

            System.debug(
                'CHAINING NEXT PAGE'
            );

            System.debug(
                'NEXT PAGE TOKEN: ' +
                nextPageToken
            );


            System.enqueueJob(
                new GoogleDriveWebhookQueueable(
                    channelId,
                    resourceId,
                    resourceState,
                    messageNumber,
                    nextPageToken
                )
            );


            System.debug(
                'NEXT QUEUEABLE ENQUEUED'
            );


            System.debug(
                '===== CURRENT QUEUEABLE FINISHED ====='
            );

            return;
        }


        // =========================================================
        // STEP 11: All Changes Successfully Processed
        // Update Salesforce Sync State
        // =========================================================

        if (!String.isBlank(newStartPageToken)) {

            state.Last_Page_Token__c =
                newStartPageToken;

System.debug('===== SYNC STATE PERMISSION CHECK =====');

System.debug('User Id: ' + UserInfo.getUserId());
System.debug('User Name: ' + UserInfo.getName());
System.debug('User Type: ' + UserInfo.getUserType());
System.debug('Profile Id: ' + UserInfo.getProfileId());

/* Object permissions */
Schema.DescribeSObjectResult syncDescribe =
    Google_Drive_Sync_State__c.SObjectType.getDescribe();

System.debug(
    'Object Accessible: ' +
    syncDescribe.isAccessible()
);

System.debug(
    'Object Createable: ' +
    syncDescribe.isCreateable()
);

System.debug(
    'Object Updateable: ' +
    syncDescribe.isUpdateable()
);

/* Field permission */
Schema.DescribeFieldResult tokenField =
    Google_Drive_Sync_State__c.Last_Page_Token__c.getDescribe();

System.debug(
    'Last_Page_Token Accessible: ' +
    tokenField.isAccessible()
);

System.debug(
    'Last_Page_Token Updateable: ' +
    tokenField.isUpdateable()
);

/* Record-level access */
UserRecordAccess accessInfo = [
    SELECT RecordId,
           HasReadAccess,
           HasEditAccess,
           HasDeleteAccess,
           MaxAccessLevel
    FROM UserRecordAccess
    WHERE UserId = :UserInfo.getUserId()
    AND RecordId = :state.Id
];

System.debug(
    'Record Id: ' +
    accessInfo.RecordId
);

System.debug(
    'Record Has Read Access: ' +
    accessInfo.HasReadAccess
);

System.debug(
    'Record Has Edit Access: ' +
    accessInfo.HasEditAccess
);

System.debug(
    'Record Has Delete Access: ' +
    accessInfo.HasDeleteAccess
);

System.debug(
    'Record Max Access Level: ' +
    accessInfo.MaxAccessLevel
);

System.debug('===== END PERMISSION CHECK =====');


            SyncStateUpdater.saveToken(state);


            System.debug(
                '===== SYNC STATE UPDATED ====='
            );

            System.debug(
                'OLD PAGE TOKEN: ' +
                pageToken
            );

            System.debug(
                'NEW PAGE TOKEN: ' +
                newStartPageToken
            );

        } else {

            System.debug(
                'NO NEW START PAGE TOKEN RETURNED'
            );
        }


        System.debug(
            '===== GOOGLE DRIVE QUEUEABLE FINISHED SUCCESSFULLY ====='
        );
    }


    // =============================================================
    // Helper: Parse Google ISO DateTime
    // =============================================================

    private static Datetime parseDateTime(
        String value
    ) {

        if (String.isBlank(value)) {
            return null;
        }


        String normalizedValue =
            value;


        Integer dotIndex =
            normalizedValue.indexOf('.');


        if (dotIndex > 0) {

            Integer zIndex =
                normalizedValue.indexOf(
                    'Z',
                    dotIndex
                );


            if (zIndex > dotIndex) {

                normalizedValue =
                    normalizedValue.substring(
                        0,
                        dotIndex
                    ) +
                    'Z';
            }
        }


        return (Datetime)
            JSON.deserialize(
                '"' +
                normalizedValue +
                '"',
                Datetime.class
            );
    }
}