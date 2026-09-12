public with sharing class LeadCaptureAction {

    public class LeadInput {

        @InvocableVariable(
            required=true
            description='The first name of the lead.'
        )
        public String firstName;

        @InvocableVariable(
            required=true
            description='The last name of the lead.'
        )
        public String lastName;

        @InvocableVariable(
            required=true
            description='The company or organization where the lead works.'
        )
        public String company;

        @InvocableVariable(
            description='The email address of the lead.'
        )
        public String email;

        @InvocableVariable(
            description='The phone number of the lead.'
        )
        public String phone;

        @InvocableVariable(
            description='The job title or position of the lead.'
        )
        public String title;

        @InvocableVariable(
            description='The industry associated with the lead or company.'
        )
        public String industry;

        @InvocableVariable(
            description='The city where the lead is located.'
        )
        public String city;

        @InvocableVariable(
            description='The state or province where the lead is located.'
        )
        public String state;

        @InvocableVariable(
            description='The country where the lead is located.'
        )
        public String country;

        @InvocableVariable(
            description='Additional information or notes about the lead.'
        )
        public String description;
    }


    public class LeadRequest {

        @InvocableVariable(
            required=true
            description='Lead information collected through the Lead Capture form.'
        )
        public LeadInput lead_data;
    }


    public class LeadOutput {

        @InvocableVariable(
            description='Result information returned after creating a Salesforce Lead.'
        )
        public LeadCaptureResult lead_result;
    }


    @InvocableMethod(
        label='Create Lead'
        description='Creates a Salesforce Lead from the lead information captured from the user.'
    )
    public static List<LeadOutput> createLead(List<LeadRequest> requests) {

        List<LeadOutput> results = new List<LeadOutput>();

        for (LeadRequest request : requests) {

            LeadInput input = request.lead_data;

            Lead lead = new Lead();

            lead.FirstName = input.firstName;
            lead.LastName = input.lastName;
            lead.Company = input.company;
            lead.Email = input.email;
            lead.Phone = input.phone;
            lead.Title = input.title;
            lead.Industry = input.industry;
            lead.City = input.city;
            lead.State = input.state;
            lead.Country = input.country;
            lead.Description = input.description;

            insert lead;


            LeadCaptureResult result = new LeadCaptureResult();

            result.leadId = lead.Id;
            result.leadName = lead.Name;
            result.success = true;
            result.message = 'Lead created successfully: ' + lead.Name;


            LeadOutput output = new LeadOutput();
            output.lead_result = result;

            results.add(output);
        }

        return results;
    }
}