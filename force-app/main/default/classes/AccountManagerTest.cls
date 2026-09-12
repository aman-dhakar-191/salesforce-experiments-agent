@isTest
private class AccountManagerTest {

    @isTest
    static void testGetAccount() {
        // --- Setup: an account with one contact ---
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Contact con = new Contact(LastName = 'Test Contact', AccountId = acc.Id);
        insert con;

        // --- Build a fake REST request pointing at this account ---
        RestRequest request = new RestRequest();
        request.requestURI =
            '/services/apexrest/Accounts/' + acc.Id + '/contacts';
        request.httpMethod = 'GET';
        RestContext.request = request;

        // --- Invoke the resource method directly ---
        Test.startTest();
        Account result = AccountManager.getAccount();
        Test.stopTest();

        // --- Verify ---
        System.assertNotEquals(null, result, 'Account should be returned');
        System.assertEquals(acc.Id, result.Id, 'Returned Id should match');
        System.assertEquals(1, result.Contacts.size(),
            'The associated contact should be included');
        System.assertEquals(con.Id, result.Contacts[0].Id,
            'Contact Id should match the inserted contact');
    }
}