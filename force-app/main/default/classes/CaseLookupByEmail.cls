public with sharing class CaseLookupByEmail {

	public class Request {
		@InvocableVariable(required=true label='Contact Email'
			description='The Contact email address to search Cases by, e.g. jane@example.com')
		public String ContactEmail;
	}

	public class Result {
		@InvocableVariable(label='Case Id'
			description='The record Id of the most recent matched Case; null if none found')
		public String caseId;

		@InvocableVariable(label='Case Number'
			description='The Case Number of the most recent matched Case')
		public String caseNumber;

		@InvocableVariable(label='Status'
			description='The current Status of the Case, e.g. New, Working, Closed')
		public String status;

		@InvocableVariable(label='Owner Name'
			description='The name of the Case owner (User or Queue); "Unknown" if unavailable')
		public String ownerName;

		@InvocableVariable(label='Found'
			description='True if a matching Case was found, false otherwise')
		public Boolean found;
	}

    @InvocableMethod(label='Find Latest Case By Email'
                     description='Returns the most recent Case for a given Contact Email')
    public static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            Case c = getCase(req.ContactEmail);
            if (c == null) {
                r.found = false;
            } else {
                r.found      = true;
                r.caseId     = c.Id;
                r.caseNumber = c.CaseNumber;
                r.status     = c.Status;
                r.ownerName  = (c.Owner != null) ? c.Owner.Name : 'Unknown';
            }
            results.add(r);
        }
        return results;
    }

    private static Case getCase(String email) {
        if (String.isBlank(email)) return null;
        List<Case> cases = [
            SELECT Id, CaseNumber, Status, Owner.Name
            FROM Case
            WHERE Contact.Email = :email
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return cases.isEmpty() ? null : cases[0];
    }
}