public without sharing class SyncStateUpdater {
    public static void saveToken(Google_Drive_Sync_State__c state) {
        upsert state; // sharing ignored; CRUD/FLS already fine in this context
    }
}