@RestResource(urlMapping='/google-drive/webhook/*')
global with sharing class GoogleDriveWebhook {

    @HttpPost
    global static void receiveNotification() {

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        System.debug('===== GOOGLE DRIVE WEBHOOK RECEIVED =====');

        String channelId =
            req.headers.get('X-Goog-Channel-ID');

        String resourceId =
            req.headers.get('X-Goog-Resource-ID');

        String resourceState =
            req.headers.get('X-Goog-Resource-State');

        String messageNumber =
            req.headers.get('X-Goog-Message-Number');

        String channelToken =
            req.headers.get('X-Goog-Channel-Token');

        System.debug('Channel ID: ' + channelId);
        System.debug('Resource ID: ' + resourceId);
        System.debug('Resource State: ' + resourceState);
        System.debug('Message Number: ' + messageNumber);
        System.debug('Channel Token: ' + channelToken);


        // Directly enqueue asynchronous processing
        // option 1 not working
        // System.enqueueJob(
        //     new GoogleDriveWebhookQueueable(
        //         channelId,
        //         resourceId,
        //         resourceState,
        //         messageNumber
        //     )
        // );
        // option 2 trying
        EventBus.publish(new Google_Drive_Webhook_Event__e(
            Channel_ID__c     = channelId,
            Resource_ID__c    = resourceId,
            Resource_State__c = resourceState,
            Message_Number__c = messageNumber
        ));

        System.debug(
            'GoogleDriveWebhookQueueable enqueued successfully.'
        );


        // Google expects an empty successful response
        res.statusCode = 204;
    }
}