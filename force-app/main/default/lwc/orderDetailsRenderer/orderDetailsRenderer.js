import { LightningElement, api } from 'lwc';

export default class OrderDetailsRenderer extends LightningElement {

    @api value;

    get order() {
        return this.value || {};
    }
}