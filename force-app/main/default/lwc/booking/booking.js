import { LightningElement } from 'lwc';

export default class Booking extends LightningElement {

    currentStep = 1;

    fullName;
    companyName;
    email;
    phone;

    employeeSize;
    userCount;
    crmType;
    selectedClouds = [];
    selectedFeatures = [];
    messageVolume;

    employeeOptions = [
        { label: 'Just Me', value: '1' },
        { label: '2 - 5 Employees', value: '2-5' },
        { label: '5 - 20 Employees', value: '5-20' },
        { label: '20+ Employees', value: '20+' }
    ];

    userOptions = [
        { label: '1 User', value: '1' },
        { label: '2 - 5 Users', value: '2-5' },
        { label: '5 - 10 Users', value: '5-10' },
        { label: '10+ Users', value: '10+' }
    ];

    crmOptions = [
        { label: 'No CRM', value: 'none' },
        { label: 'Excel Only', value: 'excel' },
        { label: 'Salesforce', value: 'salesforce' },
        { label: 'HubSpot', value: 'hubspot' },
        { label: 'Other CRM', value: 'other' }
    ];

    salesforceOptions = [
        { label: 'Sales Cloud', value: 'sales' },
        { label: 'Service Cloud', value: 'service' },
        { label: 'Experience Cloud', value: 'experience' },
        { label: 'Marketing Cloud', value: 'marketing' }
    ];

    featureOptions = [
        { label: 'Email Campaigns', value: 'email' },
        { label: 'SMS Notifications', value: 'sms' },
        { label: 'Sales Reporting', value: 'reporting' },
        { label: 'Customer Tracking', value: 'tracking' },
        { label: 'Website Lead Forms', value: 'forms' },
        { label: 'Customer Portal', value: 'portal' },
        { label: 'WhatsApp Integration', value: 'whatsapp' }
    ];

    messageOptions = [
        { label: '0 - 100', value: '100' },
        { label: '100 - 1000', value: '1000' },
        { label: '1000 - 5000', value: '5000' },
        { label: '5000+', value: '5000+' }
    ];

    get isStep1() {
        return this.currentStep === 1;
    }

    get isStep2() {
        return this.currentStep === 2;
    }

    get isStep3() {
        return this.currentStep === 3;
    }

    get isStep4() {
        return this.currentStep === 4;
    }

    get isStep5() {
        return this.currentStep === 5;
    }

    get showSalesforceOptions() {
        return this.crmType === 'salesforce';
    }

    get step1Class() {
        return this.currentStep >= 1 ? 'step active' : 'step';
    }

    get step2Class() {
        return this.currentStep >= 2 ? 'step active' : 'step';
    }

    get step3Class() {
        return this.currentStep >= 3 ? 'step active' : 'step';
    }

    get step4Class() {
        return this.currentStep >= 4 ? 'step active' : 'step';
    }

    get step5Class() {
        return this.currentStep >= 5 ? 'step active' : 'step';
    }

    handleNext() {
        if(this.currentStep < 5) {
            this.currentStep++;
        }
    }

    handlePrevious() {
        if(this.currentStep > 1) {
            this.currentStep--;
        }
    }

}