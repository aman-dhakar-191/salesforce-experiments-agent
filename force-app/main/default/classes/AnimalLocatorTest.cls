@isTest
private class AnimalLocatorTest {

    // inner class — implements the interface, lives inside the test
    @isTest
    static void testGetAnimalNameById() {
        Test.setMock(HttpCalloutMock.class, new AnimalLocatorMock());

        Test.startTest();
        String result = AnimalLocator.getAnimalNameById(1);
        Test.stopTest();

        System.assertEquals('chicken', result);
    }
}