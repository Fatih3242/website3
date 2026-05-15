import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import lead1 from '@salesforce/resourceUrl/lead';

export default class Lead extends NavigationMixin(LightningElement) {

    heroImage = lead1;

    get hasImage() {
        return this.heroImage;
    }

    handleNavigation(event) {
        let targetPageApiName = 'Home'; // Hata durumunda ana sayfaya dönmesi için varsayılan

        
       
            targetPageApiName = 'booking__c';
        

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
