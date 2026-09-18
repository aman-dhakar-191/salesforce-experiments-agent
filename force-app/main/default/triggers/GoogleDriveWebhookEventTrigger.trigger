trigger GoogleDriveWebhookEventTrigger
    on Google_Drive_Webhook_Event__e (after insert) {

    for (Google_Drive_Webhook_Event__e eventRecord : Trigger.New) {

        System.enqueueJob(
            new GoogleDriveWebhookQueueable(
                eventRecord.Channel_ID__c,
                eventRecord.Resource_ID__c,
                eventRecord.Resource_State__c,
                eventRecord.Message_Number__c
            )
        );
    }
}