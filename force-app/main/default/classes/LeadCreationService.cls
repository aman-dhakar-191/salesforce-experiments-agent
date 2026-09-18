public with sharing class LeadCreationService {

    public static Lead buildLead(
        LeadExtractionService.LeadData leadData
    ) {
        if (leadData == null) {
            throw new LeadCreationException(
                'Lead data cannot be null.'
            );
        }

        if (String.isBlank(leadData.lastName)) {
            throw new LeadCreationException(
                'Last Name is required.'
            );
        }

        if (String.isBlank(leadData.company)) {
            throw new LeadCreationException(
                'Company is required.'
            );
        }

        Lead newLead = new Lead();

        newLead.FirstName = leadData.firstName;
        newLead.LastName = leadData.lastName;
        newLead.Company = leadData.company;
        newLead.Email = leadData.email;
        newLead.Phone = leadData.phone;
        newLead.Description = leadData.description;

        return newLead;
    }

    public class LeadCreationException extends Exception {}
}