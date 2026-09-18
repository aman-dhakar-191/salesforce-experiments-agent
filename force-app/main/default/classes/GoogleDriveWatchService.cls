public with sharing class GoogleDriveWatchService {

    public static String getStartPageToken() {

        HttpRequest req = new HttpRequest();

        req.setEndpoint(
            'callout:GoogleDrive/drive/v3/changes/startPageToken'
        );

        req.setMethod('GET');

        Http http = new Http();

        HttpResponse res = http.send(req);

        System.debug('===== GOOGLE DRIVE START PAGE TOKEN =====');
        System.debug('Status Code: ' + res.getStatusCode());
        System.debug('Response: ' + res.getBody());

        if (res.getStatusCode() != 200) {
            throw new CalloutException(
                'Failed to get Google Drive start page token: ' +
                res.getBody()
            );
        }

        Map<String, Object> response =
            (Map<String, Object>) JSON.deserializeUntyped(
                res.getBody()
            );

        String startPageToken =
            (String) response.get('startPageToken');

        System.debug(
            'START PAGE TOKEN: ' + startPageToken
        );

        return startPageToken;
    }


    public static void createWatchChannel(String pageToken) {

        String channelId = System.Label.Google_Drive_Channel_Id;

String webhookUrl =
    'https://orgfarm-abe6109e32-dev-ed.develop.my.salesforce-sites.com' +
    '/services/apexrest/google-drive/webhook';

        HttpRequest req = new HttpRequest();

        req.setEndpoint(
            'callout:GoogleDrive/drive/v3/changes/watch?pageToken=' +
            EncodingUtil.urlEncode(pageToken, 'UTF-8')
        );

        req.setMethod('POST');

        req.setHeader(
            'Content-Type',
            'application/json'
        );

		Long expiration =
			DateTime.now().getTime() + 604800000L;

		Map<String, Object> body =
			new Map<String, Object>{
				'id' => channelId,
				'type' => 'web_hook',
				'address' => webhookUrl,
				'expiration' => expiration
			};

        req.setBody(JSON.serialize(body));

        System.debug('===== CREATING GOOGLE DRIVE WATCH =====');
        System.debug('Channel ID: ' + channelId);
        System.debug('Webhook URL: ' + webhookUrl);
        System.debug('Page Token: ' + pageToken);

        Http http = new Http();

        HttpResponse res = http.send(req);

        System.debug(
            'Status Code: ' + res.getStatusCode()
        );

        System.debug(
            'Response: ' + res.getBody()
        );

        if (res.getStatusCode() < 200 ||
            res.getStatusCode() >= 300) {

            throw new CalloutException(
                'Failed to create Google Drive watch: ' +
                res.getBody()
            );
        }
    }
}