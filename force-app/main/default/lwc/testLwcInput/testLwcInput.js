import { LightningElement, api } from 'lwc';

export default class TestLwcInput extends LightningElement {
    @api value;

    handleChange(event) {
        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail: { value: { meetingNote: event.target.value } }
            })
        );
    }
}