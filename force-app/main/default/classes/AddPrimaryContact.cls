public class AddPrimaryContact implements Queueable {

    private Contact contactToAdd;
    private String stateAbbr;

    public AddPrimaryContact(Contact c, String state) {
        this.contactToAdd = c;
        this.stateAbbr = state;
    }

    public void execute(QueueableContext context) {
        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE BillingState = :stateAbbr
            LIMIT 200
        ];

        List<Contact> contactsToInsert = new List<Contact>();
        for (Account acc : accounts) {
            Contact clonedContact = contactToAdd.clone(false, false, false, false);
            clonedContact.AccountId = acc.Id;
            contactsToInsert.add(clonedContact);
        }
        insert contactsToInsert;
    }
}