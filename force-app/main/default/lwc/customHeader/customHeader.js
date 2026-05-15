import { LightningElement } from 'lwc';
import KLOD_LOGO_RESOURCE from '@salesforce/resourceUrl/Klod';
import { NavigationMixin } from 'lightning/navigation';
export default class CustomHeader extends NavigationMixin(LightningElement) {
    logoUrl = KLOD_LOGO_RESOURCE;
    handleServiceSelect(event) {
     

     // HTML'deki data-id değerini alıyoruz ("sales", "service" veya "agent")
        const selectedServiceId = event.currentTarget.dataset.id;
        
        // Salesforce'un builder tarafındaki sayfa API adını tutacak değişken
        let targetPageApiName = 'Home'; // Hata durumunda ana sayfaya dönmesi için varsayılan

        // Tıklanan id değerine göre hangi sayfaya gidileceğini eşleştiriyoruz
        if (selectedServiceId === 'mail') {
            targetPageApiName = 'EmailAutomationService__c'; // Sizin açtığınız "sales" sayfasının API adı
        } else if (selectedServiceId === 'report') {
            targetPageApiName = 'report__c'; // Sizin açtığınız "service" sayfasının API adı
        } else if (selectedServiceId === 'customer') {
            targetPageApiName = 'customer__c'; // Sizin açtığınız "agent" sayfasının API adı
        }  else if (selectedServiceId === 'sms') {
            targetPageApiName = 'sms__c'; // Sizin açtığınız "service" sayfasının API adı
        } else if (selectedServiceId === 'lead') {
            targetPageApiName = 'lead__c'; // Sizin açtığınız "agent" sayfasının API adı
        }else if (selectedServiceId === 'ownportal') {
            targetPageApiName = 'ownportal__c'; // Sizin açtığınız "service" sayfasının API adı
        } 

        // Salesforce LWR uyumlu yönlendirme tetikleyicisi
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage', // Deneyim siteleri için standart sayfa tipi
            attributes: {
                name: targetPageApiName // Builder'daki tam API adını buraya gönderiyoruz
            }
        });

        window.scrollTo({
            top: 0,
            left: 0,
            behavior: 'smooth' // Sayfanın yumuşak bir kayma efektiyle yukarı çıkmasını sağlar
        });
    }
}
