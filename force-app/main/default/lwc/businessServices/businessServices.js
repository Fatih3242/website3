import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class BusinessServices extends NavigationMixin(LightningElement) {

    handleServiceSelect(event) {
     

     // HTML'deki data-id değerini alıyoruz ("sales", "service" veya "agent")
        const selectedServiceId = event.currentTarget.dataset.id;
        
        // Salesforce'un builder tarafındaki sayfa API adını tutacak değişken
        let targetPageApiName = 'Home'; // Hata durumunda ana sayfaya dönmesi için varsayılan

        // Tıklanan id değerine göre hangi sayfaya gidileceğini eşleştiriyoruz
        if (selectedServiceId === 'mail') {
            targetPageApiName = 'EmailAutomationService__c'; // Sizin açtığınız "sales" sayfasının API adı
        } else if (selectedServiceId === 'report') {
            targetPageApiName = 'EmailAutomationService__c';
        } else if (selectedServiceId === 'customer') {
            targetPageApiName = 'EmailAutomationService__c'; 
        } else if (selectedServiceId === 'sms') {
            targetPageApiName = 'EmailAutomationService__c'; 
        } else if (selectedServiceId === 'lead') {
            targetPageApiName = 'EmailAutomationService__c';  // Sizin açtığınız "service" sayfasının API adı
        } else if (selectedServiceId === 'ownportal') {
            targetPageApiName = 'EmailAutomationService__c'; // Sizin açtığınız "agent" sayfasının API adı
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