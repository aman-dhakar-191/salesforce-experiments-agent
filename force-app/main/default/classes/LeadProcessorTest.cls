@isTest
private class LeadProcessorTest {

    @testSetup
    static void makeData() {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 200; i++) {
            leads.add(new Lead(
                LastName = 'Lead ' + i,
                Company = 'Test Company ' + i
            ));
        }
        insert leads;
    }

    @isTest
    static void testLeadProcessorBatch() {
        Test.startTest();
        LeadProcessor batch = new LeadProcessor();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        Integer updatedCount = [
            SELECT COUNT()
            FROM Lead
            WHERE LeadSource = 'Dreamforce'
        ];
        System.assertEquals(200, updatedCount,
            'All 200 leads should have LeadSource = Dreamforce');
    }
}