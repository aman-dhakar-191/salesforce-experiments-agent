import { LightningElement, api } from 'lwc';

export default class LeadCaptureForm extends LightningElement {

    @api value;

    firstName = '';
    lastName = '';
    company = '';
    email = '';
    phone = '';
    title = '';
    industry = '';
    city = '';
    state = '';
    country = '';
    description = '';

    handleChange(event) {
        const field = event.target.name;

        this[field] = event.target.value;

        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail: {
                    value: {
                        firstName: this.firstName,
                        lastName: this.lastName,
                        company: this.company,
                        email: this.email,
                        phone: this.phone,
                        title: this.title,
                        industry: this.industry,
                        city: this.city,
                        state: this.state,
                        country: this.country,
                        description: this.description
                    }
                }
            })
        );
    }
}