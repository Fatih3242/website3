import { LightningElement, track } from 'lwc';

export default class Contact extends LightningElement {

    @track fullName = '';
    @track email = '';
    @track company = '';
    @track topic = '';
    @track message = '';

    @track termsAccepted = false;
    @track marketingConsent = false;

    handleFullName(event){

        this.fullName = event.target.value;

    }

    handleEmail(event){

        this.email = event.target.value;

    }

    handleCompany(event){

        this.company = event.target.value;

    }

    handleTopic(event){

        this.topic = event.target.value;

    }

    handleMessage(event){

        this.message = event.target.value;

    }

    handleTermsConsent(event){

        this.termsAccepted =
            event.target.checked;

    }

    handleMarketingConsent(event){

        this.marketingConsent =
            event.target.checked;

    }

    handleSubmit(){

        console.log('contact submitted');

    }

}