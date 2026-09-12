global with sharing class TimeSlotAction {

    global class TimeSlotRequest {

        @InvocableVariable(
            required=true
            description='Time slot selected by the user.'
        )
        global TimeSlotInput selected_slot;
    }

    global class TimeSlotOutput {

        @InvocableVariable(
            description='The selected time slot.'
        )
        global TimeSlotInput selected_slot;
    }

    @InvocableMethod(
        label='Select Time Slot'
        description='Allows the user to select a date and time slot.'
    )
    global static List<TimeSlotOutput> selectTimeSlot(
        List<TimeSlotRequest> requests
    ) {

        List<TimeSlotOutput> results = new List<TimeSlotOutput>();

        for (TimeSlotRequest request : requests) {

            TimeSlotOutput output = new TimeSlotOutput();

            output.selected_slot = request.selected_slot;

            results.add(output);
        }

        return results;
    }
}