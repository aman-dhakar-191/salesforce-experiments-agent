@isTest
private class ParkLocatorTest {
    @isTest
    static void testCountry() {
        Test.setMock(WebServiceMock.class, new ParkServiceMock());

        Test.startTest();
        List<String> result = ParkLocator.country('India');
        Test.stopTest();

        System.assertEquals(
            new List<String>{ 'Park1', 'Park2', 'Park3' },
            result,
            'Mock should return the three fake park names');
    }
}