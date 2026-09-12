@isTest
private class DailyLeadProcessorTest {

    // Cron expression: fire once at a fixed future time (required by scheduleJob)
    private static final String CRON_EXP = '0 0 0 15 3 ? 2042';

    @testSetup
    static void makeData() {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 200; i++) {
            leads.add(new Lead(
                LastName = 'Lead ' + i,
                Company = 'Test Company ' + i
                // LeadSource intentionally left blank
            ));
        }
        insert leads;
    }

    @isTest
    static void testDailyLeadProcessorSchedule() {
        Test.startTest();
        // Scheduling inside start/stop forces the job to run at stopTest()
        String jobId = System.schedule('Test Daily Lead Process', CRON_EXP, new DailyLeadProcessor());
        Test.stopTest();

        Integer updatedCount = [
            SELECT COUNT()
            FROM Lead
            WHERE LeadSource = 'Dreamforce'
        ];
        System.assertEquals(200, updatedCount,
            'All 200 blank-source leads should be updated to Dreamforce');
    }
}