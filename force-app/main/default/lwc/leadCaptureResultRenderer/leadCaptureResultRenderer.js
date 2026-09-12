import { LightningElement, api } from 'lwc';

export default class LeadCaptureResultRenderer extends LightningElement {

    @api value;

    get leadId() {
        return this.value?.leadId;
    }

    get leadName() {
        return this.value?.leadName;
    }

    get message() {
        return this.value?.message;
    }

    get success() {
        return this.value?.success;
    }
}