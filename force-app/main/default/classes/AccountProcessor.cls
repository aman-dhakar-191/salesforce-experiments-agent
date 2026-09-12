public class AccountProcessor {
    @future
    public static void countContacts(List<Id> accountIds) {
		if(accountIds ==null || accountIds.size() == 0){
			return;
		}
        List<AggregateResult> results = [
            SELECT COUNT(Id) totalContacts, AccountId
            FROM Contact
            WHERE AccountId IN :accountIds
            GROUP BY AccountId
        ];
        List<Account> accountsToUpdate = new List<Account>();
        for (AggregateResult result : results) {
            Id accountId = (Id) result.get('AccountId');
            Integer totalContacts = (Integer) result.get('totalContacts');
            accountsToUpdate.add(new Account(
                Id = accountId,
                Number_Of_Contacts__c = totalContacts
            ));
        }
        update accountsToUpdate;
    }
}