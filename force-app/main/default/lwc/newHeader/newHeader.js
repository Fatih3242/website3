import { LightningElement } from 'lwc';

import KLOD_LOGO_RESOURCE
from '@salesforce/resourceUrl/Klod';

import { NavigationMixin }
from 'lightning/navigation';

export default class NewHeader
extends NavigationMixin(LightningElement) {

    logoUrl = KLOD_LOGO_RESOURCE;

    handleServiceSelect(event) {

        event.preventDefault();

        const selectedServiceId =
            event.currentTarget.dataset.id;

        let targetPageApiName = 'Home';

        if (selectedServiceId === 'mail') {

            targetPageApiName =
                'EmailAutomationService__c';

        }
        else if (selectedServiceId === 'report') {

            targetPageApiName =
                'report__c';

        }
        else if (selectedServiceId === 'customer') {

            targetPageApiName =
                'customer__c';

        }
        else if (selectedServiceId === 'sms') {

            targetPageApiName =
                'sms__c';

        }
        else if (selectedServiceId === 'lead') {

            targetPageApiName =
                'lead__c';

        }
        else if (selectedServiceId === 'ownportal') {

            targetPageApiName =
                'ownportal__c';

        }

        this[NavigationMixin.Navigate]({

            type:'comm__namedPage',

            attributes:{

                name:targetPageApiName

            }

        });

        window.scrollTo({
            top: 0,
            left: 0,
            behavior: 'smooth' // Sayfanın yumuşak bir kayma efektiyle yukarı çıkmasını sağlar
        });

    }

}