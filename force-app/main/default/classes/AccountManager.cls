@RestResource(urlMapping='/Accounts/*/contacts')
global class AccountManager {

    @HttpGet
    global static Account getAccount() {
        RestRequest request = RestContext.request;
        // URL looks like: /services/apexrest/Accounts/001.../contacts
        // Grab the Id: strip '/contacts' from the end, then take the last path segment.
        String accountId = request.requestURI.substringBetween('Accounts/', '/contacts');

        Account result = [
            SELECT Id, Name,
                   (SELECT Id, Name FROM Contacts)
            FROM Account
            WHERE Id = :accountId
        ];
        return result;
    }
}