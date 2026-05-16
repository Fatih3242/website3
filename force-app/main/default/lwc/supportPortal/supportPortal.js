import { LightningElement, track } from 'lwc';

import saveSupportRequest
from '@salesforce/apex/SupportPageController.saveSupportRequest';

export default class SupportPortal
extends LightningElement {

    /* FORM */

    @track fullName = '';
    @track email = '';
    @track company = '';
    @track category = '';
    @track message = '';
    @track priority = '';

    /* CONSENTS */

    @track termsAccepted = false;
    @track marketingConsent = false;

    /* UI STATES */

    @track isSubmitting = false;

    @track isSubmittedSuccessfully = false;

    @track submitErrorMessage = '';

    /* INPUTS */

    handleFullName(event) {

        this.fullName =
            event.target.value;

    }

    handleEmail(event) {

        this.email =
            event.target.value;

    }

    handleCompany(event) {

        this.company =
            event.target.value;

    }

    handleCategory(event) {

        this.category =
            event.target.value;

    }

    handleMessage(event) {

        this.message =
            event.target.value;

    }

    handleTermsConsent(event) {

        this.termsAccepted =
            event.target.checked;

    }

    handleMarketingConsent(event) {

        this.marketingConsent =
            event.target.checked;

    }

    handlePriority(event) {

        this.priority =
            event.currentTarget.dataset.value;

    }

    /* SUBMIT */

    async handleSubmit() {

        /* RESET */

        this.submitErrorMessage = '';

        /* BLOCK DOUBLE CLICK */

        if (this.isSubmitting) {

            return;

        }

        /* EMAIL VALIDATION */

        const emailInput =
            this.template.querySelector(
                '[data-id="supportEmailField"]'
            );

        if (
            !emailInput ||
            !emailInput.checkValidity()
        ) {

            emailInput.reportValidity();

            return;

        }

        /* PRIORITY REQUIRED */

        if (!this.priority) {

            this.submitErrorMessage =
                'Please select a priority level before submitting your support request.';

            return;

        }

        /* TERMS REQUIRED */

        if (!this.termsAccepted) {

            this.submitErrorMessage =
                'Please accept the Privacy Policy and Terms of Service to continue.';

            return;

        }

        this.isSubmitting = true;

        try {

            await saveSupportRequest({

                fullName:
                    this.fullName,

                email:
                    this.email,

                company:
                    this.company,

                category:
                    this.category,

                message:
                    this.message,

                priority:
                    this.priority,

                marketingConsent:
                    this.marketingConsent

            });

            /* SUCCESS */

            this.isSubmittedSuccessfully =
                true;

        }
        catch(error) {

            console.error(
                'SUPPORT REQUEST ERROR:',
                JSON.stringify(error)
            );

            this.submitErrorMessage =
                'We were unable to submit your support request at this time. Please try again in a few moments.';

        }
        finally {

            this.isSubmitting = false;

        }

    }

    /* PRIORITY DESIGN */

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