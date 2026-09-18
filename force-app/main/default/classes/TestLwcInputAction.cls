global with sharing class TestLwcInputAction {

    global class Request {
        @InvocableVariable(required=true description='A simple text note.')
        global String meetingNote;
    }

    global class Output {
        @InvocableVariable(description='The note received.')
        global String meetingNote;
    }

    @InvocableMethod(label='Test LWC Input' description='Simple test for LWC rendering in Agentforce.')
    global static List<Output> execute(List<Request> requests) {
        List<Output> results = new List<Output>();
        for (Request r : requests) {
            Output o = new Output();
            o.meetingNote = r.meetingNote;
            results.add(o);
        }
        return results;
    }
}