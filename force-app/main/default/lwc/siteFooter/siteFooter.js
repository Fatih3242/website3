import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import LOGO from '@salesforce/resourceUrl/Klod';

export default class SiteFooter extends NavigationMixin(
    LightningElement
) {

    logoUrl = LOGO;



    navigateToPage(event) {

        const selectedServiceId = event.currentTarget.dataset.id;
        
        // Salesforce'un builder tarafındaki sayfa API adını tutacak değişken
        let targetPageApiName = 'Home'; // Hata durumunda ana sayfaya dönmesi için varsayılan

        // Tıklanan id değerine göre hangi sayfaya gidileceğini eşleştiriyoruz
        if (selectedServiceId === 'aboutUs__c') {
            targetPageApiName = 'aboutUs__c'; // Sizin açtığınız "sales" sayfasının API adı
        } else if (selectedServiceId === 'Contact__c') {
            targetPageApiName = 'Contact__c';
        } else if (selectedServiceId === 'Careers__c') {
            targetPageApiName = 'Careers__c'; 
        } else if (selectedServiceId === 'supportPortal__c') {
            targetPageApiName = 'supportPortal__c'; 
        } else if (selectedServiceId === 'booking__c') {
            targetPageApiName = 'booking__c';  // Sizin açtığınız "service" sayfasının API adı
        } else if (selectedServiceId === 'systems__c') {
            targetPageApiName = 'systems__c'; // Sizin açtığınız "agent" sayfasının API adı
        } else if (selectedServiceId === 'privacy__c') {
            targetPageApiName = 'Privacy__c';
        } else if (selectedServiceId === 'terms__c') {
            targetPageApiName = 'terms__c'; 
        } else if (selectedServiceId === 'Cookie__c') {
            targetPageApiName = 'Cookie__c'; 
        } else if (selectedServiceId === 'Subscriber__c') {
            targetPageApiName = 'Subscriber__c';  
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



    /*
        EXPERIENCE CLOUD URL FORMAT
        /s/page-name
    

    aboutUrl = '/s/aboutUs__c';
    contactUrl = '/s/contact';
    careersUrl = '/s/careers';

    supportUrl = '/s/supportPortal';
    bookingUrl = '/s/booking';
    systemUrl = '/s/systems';

    privacyUrl = '/s/privacy';
    termsUrl = '/s/terms';
    cookieUrl = '/s/cookie';
    subscriberUrl = '/s/subscriber';  */

}