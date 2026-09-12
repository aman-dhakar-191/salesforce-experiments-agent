import { LightningElement, api } from 'lwc';

export default class TimeSlotSelector extends LightningElement {

    @api value;

    selectedDate = '';
    selectedTime = '';

    handleDateChange(event) {
        this.selectedDate = event.target.value;

        this.sendValue();
    }

    handleTimeChange(event) {
        this.selectedTime = event.target.dataset.time;

        this.sendValue();
    }

    sendValue() {

        if (!this.selectedDate || !this.selectedTime) {
            return;
        }

        const selectedDateTime =
            `${this.selectedDate}T${this.selectedTime}:00+05:30`;

        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail: {
                    value: {
                        selectedDate: this.selectedDate,
                        selectedTime: this.selectedTime,
                        selectedDateTime: selectedDateTime,
                        timezone: 'Asia/Kolkata'
                    }
                }
            })
        );
    }
}