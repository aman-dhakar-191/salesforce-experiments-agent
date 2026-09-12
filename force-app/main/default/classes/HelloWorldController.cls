public with sharing class HelloWorldController {
    @AuraEnabled(cacheable=true)
    public static String getGreeting() {
        return 'Hello from Salesforce CI/CD via GitHub Actions!';
    }
}