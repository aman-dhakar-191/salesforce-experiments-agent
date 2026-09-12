public with sharing class CaseLookupByNumber {

	public class Request {
		@InvocableVariable(required=true label='Case Number'
			description='The Case Number to look up, e.g. 00001234')
		public String CaseNumber;
	}

	public class Result {
		@InvocableVariable(label='Case Id'
			description='The record Id of the matched Case; null if no Case was found')
		public String caseId;

		@InvocableVariable(label='Case Number'
			description='The Case Number of the matched Case')
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

    @InvocableMethod(label='Find Case By Number'
                     description='Returns the Case matching the given Case Number')
    public static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            Case c = getCase(req.CaseNumber);
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

    private static Case getCase(String caseNumber) {
        if (String.isBlank(caseNumber)) return null;
        List<Case> cases = [
            SELECT Id, CaseNumber, Status, Owner.Name
            FROM Case
            WHERE CaseNumber = :caseNumber
            WITH USER_MODE
            LIMIT 1
        ];
        return cases.isEmpty() ? null : cases[0];
    }
}