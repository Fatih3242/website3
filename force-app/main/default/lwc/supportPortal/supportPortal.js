import { LightningElement, track } from 'lwc';

export default class SupportPortal extends LightningElement {

    @track fullName = '';
    @track email = '';
    @track company = '';
    @track category = '';
    @track message = '';
    @track priority = '';
    @track termsAccepted = false;
    @track marketingConsent = false;

    handleTermsConsent(event) {

    this.termsAccepted =
        event.target.checked;

    }

    handleMarketingConsent(event) {

        this.marketingConsent =
            event.target.checked;

    }

    handleSubmit() {

    console.log('support submitted');

    }
    handleFullName(event) {

        this.fullName = event.target.value;

    }

    handleEmail(event) {

        this.email = event.target.value;

    }

    handleCompany(event) {

        this.company = event.target.value;

    }

    handleCategory(event) {

        this.category = event.target.value;

    }

    handleMessage(event) {

        this.message = event.target.value;

    }

    handlePriority(event) {

        this.priority =
            event.currentTarget.dataset.value;

    }

    get lowClass() {

        return this.priority === 'Low'
            ? 'priority-card selected'
            : 'priority-card';

    }

    get mediumClass() {

        return this.priority === 'Medium'
            ? 'priority-card selected'
            : 'priority-card';

    }

    get highClass() {

        return this.priority === 'High'
            ? 'priority-card selected'
            : 'priority-card';

    }

}