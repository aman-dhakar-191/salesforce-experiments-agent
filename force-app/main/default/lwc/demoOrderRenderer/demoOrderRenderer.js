import { LightningElement, api } from 'lwc';

export default class DemoOrderRenderer extends LightningElement {

    @api value;

    connectedCallback() {
        console.log(
            'Demo Order CLT Renderer value:',
            JSON.stringify(this.value)
        );
    }
}