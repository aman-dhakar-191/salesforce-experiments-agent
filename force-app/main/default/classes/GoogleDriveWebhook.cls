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

    // Enqueue asynchronous processing
    System.enqueueJob(
        new GoogleDriveWebhookQueueable(
            channelId,
            resourceId,
            resourceState,
            messageNumber
        )
    );

    res.statusCode = 204;
}
}