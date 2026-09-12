@isTest
private class AddPrimaryContactTest {

    @testSetup
    static void makeData() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 50; i++) {
            accounts.add(new Account(
                Name = 'NY Account ' + i,
                BillingCountry = 'United States',
                BillingState = 'New York'
            ));
        }
        for (Integer i = 0; i < 50; i++) {
            accounts.add(new Account(
                Name = 'CA Account ' + i,
                BillingCountry = 'United States',
                BillingState = 'California'
            ));
        }
        insert accounts;
    }

    @isTest
    static void testAddPrimaryContact() {
        Contact template = new Contact(LastName = 'Primary Contact');

        Test.startTest();
        AddPrimaryContact job = new AddPrimaryContact(template, 'California');
        System.enqueueJob(job);
        Test.stopTest();

        Integer caContacts = [
            SELECT COUNT()
            FROM Contact
            WHERE Account.BillingState = 'California'
        ];
        System.assertEquals(50, caContacts,
            'A contact should be inserted for each of the 50 CA accounts');

        Integer nyContacts = [
            SELECT COUNT()
            FROM Contact
            WHERE Account.BillingState = 'New York'
        ];
        System.assertEquals(0, nyContacts,
            'NY accounts should have no contacts inserted');
    }
}