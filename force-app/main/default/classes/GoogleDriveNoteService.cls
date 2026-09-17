/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : GoogleDriveNoteService
 * Author          : <YourName>
 * Created Date    : Sep 16, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Sep 16, 2026
 * Description     : Service class for detecting Google Drive meeting notes
 *                   and synchronizing file information with Salesforce.
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Sep 16, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class GoogleDriveNoteService {

    /*
     * Google Drive folder containing meeting notes.
     */
    private static final String FOLDER_ID =
        System.Label.Google_Drive_Folder_Id;

    /*
     * Google Drive MIME type for Google Docs.
     */
    private static final String GOOGLE_DOC_MIME_TYPE =
        'application/vnd.google-apps.document';

    /*
     * Named Credential configured in Salesforce.
     */
    private static final String NAMED_CREDENTIAL =
        'GoogleDrive';


    /**
     * Detect Google Docs in the configured Google Drive folder
     * and synchronize them into Google_Drive_File__c.
     */
    public static void syncNotes() {

        List<GoogleDriveFile> driveFiles =
            getDriveFiles();

        if (driveFiles.isEmpty()) {

            System.debug(
                'No Google Docs found in the configured folder.'
            );

            return;
        }

        Set<String> googleFileIds =
            new Set<String>();

        for (GoogleDriveFile file : driveFiles) {
            googleFileIds.add(file.id);
        }

        /*
         * Find files that Salesforce has already seen.
         */
        Map<String, Google_Drive_File__c> existingFilesByGoogleId =
            new Map<String, Google_Drive_File__c>();

        for (Google_Drive_File__c record : [
            SELECT
                Id,
                Google_File_Id__c,
                Processed__c,
                Processing_Status__c
            FROM Google_Drive_File__c
            WHERE Google_File_Id__c IN :googleFileIds
        ]) {

            existingFilesByGoogleId.put(
                record.Google_File_Id__c,
                record
            );
        }

        List<Google_Drive_File__c> recordsToInsert =
            new List<Google_Drive_File__c>();

        List<Google_Drive_File__c> recordsToUpdate =
            new List<Google_Drive_File__c>();

        for (GoogleDriveFile file : driveFiles) {

            /*
             * File already exists in Salesforce.
             */
            if (existingFilesByGoogleId.containsKey(file.id)) {

                Google_Drive_File__c existingRecord =
                    existingFilesByGoogleId.get(file.id);

                /*
                 * Update Google modified date in case
                 * the meeting note was changed.
                 */
                existingRecord.Google_Modified_Date__c =
                    parseDateTime(file.modifiedTime);

                recordsToUpdate.add(existingRecord);

                continue;
            }

            /*
             * New Google Drive file.
             */
            Google_Drive_File__c newRecord =
                new Google_Drive_File__c();

            newRecord.Google_File_Id__c =
                file.id;

            newRecord.File_Name__c =
                file.name;

            newRecord.File_Type__c =
                'Google Doc';

            newRecord.File_URL__c =
                file.webViewLink;

            newRecord.Mime_Type__c =
                file.mimeType;

            newRecord.Google_Created_Date__c =
                parseDateTime(file.createdTime);

            newRecord.Google_Modified_Date__c =
                parseDateTime(file.modifiedTime);

            newRecord.Processed__c =
                false;

            newRecord.Processing_Status__c =
                'New';

            recordsToInsert.add(newRecord);
        }

        /*
         * Insert newly discovered files.
         */
        if (!recordsToInsert.isEmpty()) {

            insert recordsToInsert;

            System.debug(
                'Inserted Google Drive records: ' +
                recordsToInsert.size()
            );
        }

        /*
         * Update existing files.
         */
        if (!recordsToUpdate.isEmpty()) {

            update recordsToUpdate;

            System.debug(
                'Updated Google Drive records: ' +
                recordsToUpdate.size()
            );
        }
    }


    /**
     * Get Google Docs from the configured Google Drive folder.
     *
     * Public because GoogleDriveWebhookQueueable
     * uses this method for change detection.
     */
    public static List<GoogleDriveFile> getDriveFiles() {

        String query =
            '\'' + FOLDER_ID + '\'' +
            ' in parents' +
            ' and trashed = false' +
            ' and mimeType = \'' +
            GOOGLE_DOC_MIME_TYPE +
            '\'';

        String endpoint =
            'callout:' +
            NAMED_CREDENTIAL +
            '/drive/v3/files' +
            '?q=' +
            EncodingUtil.urlEncode(
                query,
                'UTF-8'
            ) +
            '&pageSize=100' +
            '&orderBy=createdTime' +
            '&fields=files(id,name,mimeType,createdTime,modifiedTime,webViewLink)';

        HttpRequest request =
            new HttpRequest();

        request.setEndpoint(endpoint);
        request.setMethod('GET');

        Http http =
            new Http();

        HttpResponse response =
            http.send(request);

        System.debug(
            'Google Drive Status Code: ' +
            response.getStatusCode()
        );

        if (response.getStatusCode() != 200) {

            throw new GoogleDriveException(
                'Google Drive API failed. Status: ' +
                response.getStatusCode() +
                ', Body: ' +
                response.getBody()
            );
        }

        DriveFileResponse driveResponse =
            (DriveFileResponse) JSON.deserialize(
                response.getBody(),
                DriveFileResponse.class
            );

        if (
            driveResponse == null ||
            driveResponse.files == null
        ) {

            return new List<GoogleDriveFile>();
        }

        return driveResponse.files;
    }


    /**
     * Convert Google RFC3339 datetime into Salesforce DateTime.
     */
    private static Datetime parseDateTime(
        String value
    ) {

        if (String.isBlank(value)) {
            return null;
        }

        /*
         * Example Google value:
         *
         * 2026-09-16T07:02:40.700Z
         *
         * Salesforce can parse this after removing
         * the milliseconds.
         */
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

        return (Datetime) JSON.deserialize(
            '"' + normalizedValue + '"',
            Datetime.class
        );
    }


    /**
     * Google Drive API response.
     */
    private class DriveFileResponse {

        public List<GoogleDriveFile> files;
    }


    /**
     * Google Drive file.
     *
     * Public because this wrapper is consumed
     * by GoogleDriveWebhookQueueable.
     */
    public class GoogleDriveFile {

        public String id;
        public String name;
        public String mimeType;
        public String createdTime;
        public String modifiedTime;
        public String webViewLink;
    }


    /**
     * Custom exception for Google Drive errors.
     */
    public class GoogleDriveException extends Exception {
    }
}