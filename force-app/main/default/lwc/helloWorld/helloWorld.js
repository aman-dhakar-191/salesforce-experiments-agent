import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getGreeting from '@salesforce/apex/HelloWorldController.getGreeting';

export default class HelloWorld extends LightningElement {
    greeting;
    wiredGreetingResult;

    @wire(getGreeting)
    wiredGreeting(result) {
        this.wiredGreetingResult = result;
        const { data, error } = result;
        if (data) {
            this.greeting = data;
        } else if (error) {
            this.greeting = 'Error: ' + error.body.message;
        }
    }

    handleRefresh() {
        refreshApex(this.wiredGreetingResult);
    }
}
