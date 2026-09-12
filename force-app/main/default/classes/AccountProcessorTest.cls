/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name   : AccountProcessorTest
 * Description  : Unit tests for AccountProcessor.countContacts (@future).
 *                Uses @testSetup for shared data. Covers positive, boundary,
 *                and defensive-input scenarios.
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@isTest
private class AccountProcessorTest {

    @testSetup
    static void makeData() {
        // acc1: 3 contacts | acc2: 5 contacts | acc3: 0 contacts
        Account acc1 = new Account(Name = 'Acct With 3');
        Account acc2 = new Account(Name = 'Acct With 5');
        Account acc3 = new Account(Name = 'Acct With 0');
        insert new List<Account>{ acc1, acc2, acc3 };

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 3; i++) {
            contacts.add(new Contact(LastName = 'A1-' + i, AccountId = acc1.Id));
        }
        for (Integer i = 0; i < 5; i++) {
            contacts.add(new Contact(LastName = 'A2-' + i, AccountId = acc2.Id));
        }
        // acc3 intentionally gets none
        insert contacts;
    }

    @isTest
    static void testAccountsWithContacts() {
        Map<String, Id> ids = accountIdsByName();
        List<Id> input = new List<Id>{ ids.get('Acct With 3'), ids.get('Acct With 5') };

        Test.startTest();
        AccountProcessor.countContacts(input);
        Test.stopTest();

        Map<Id, Account> updated = new Map<Id, Account>([
            SELECT Id, Number_Of_Contacts__c FROM Account WHERE Id IN :input
        ]);
        System.assertEquals(3, updated.get(ids.get('Acct With 3')).Number_Of_Contacts__c,
            'Account with 3 contacts should be counted as 3');
        System.assertEquals(5, updated.get(ids.get('Acct With 5')).Number_Of_Contacts__c,
            'Account with 5 contacts should be counted as 5');
    }

    @isTest
    static void testAccountWithZeroContacts() {
        Id acc3Id = accountIdsByName().get('Acct With 0');

        Test.startTest();
        AccountProcessor.countContacts(new List<Id>{ acc3Id });
        Test.stopTest();

        Account acc3 = [SELECT Number_Of_Contacts__c FROM Account WHERE Id = :acc3Id];
        System.assertEquals(null, acc3.Number_Of_Contacts__c,
            'GROUP BY returns no row for 0-contact accounts, so field stays null');
    }

    @isTest
    static void testEmptyInput() {
        Test.startTest();
        AccountProcessor.countContacts(new List<Id>());
        Test.stopTest();
        // No exception = pass. Nothing to assert on data.
        System.assert(true, 'Empty input should complete without error');
    }

    @isTest
    static void testNullInput() {
        Test.startTest();
        AccountProcessor.countContacts(null);
        Test.stopTest();
        System.assert(true, 'Null input should complete without error');
    }

    static Map<String, Id> accountIdsByName() {
        Map<String, Id> byName = new Map<String, Id>();
        for (Account a : [SELECT Id, Name FROM Account]) {
            byName.put(a.Name, a.Id);
        }
        return byName;
    }
}