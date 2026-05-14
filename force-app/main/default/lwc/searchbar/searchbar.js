import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class CustomSearchBar extends NavigationMixin(LightningElement) {
    @track searchKey = '';

    handleInputChange(event) {
        this.searchKey = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }

    handleSearch() {
        const searchTerm = this.searchKey;

        if (searchTerm && searchTerm.trim().length > 2) {
            // LWS engelini aşmak için tüm sayfa dökümanını tarayan güvenli bir arama mekanizması başlatıyoruz
            const lowerSearchTerm = searchTerm.toLowerCase().trim();
            
            // Sayfadaki tüm görünür yazıları toplamak için tarayıcı ağacını gezer
            const walk = document.createTreeWalker(
                document.body,
                NodeFilter.SHOW_TEXT,
                null,
                false
            );

            let node;
            let found = false;

            // Kelimenin geçtiği ilk metin alanını bulana kadar sayfayı tarar
            while ((node = walk.nextNode())) {
                const text = node.nodeValue.toLowerCase();
                
                // Eğer kelime bu metin düğümünün içinde geçiyorsa ve arama kutusunun kendi metni değilse
                if (text.includes(lowerSearchTerm) && !node.parentElement.closest('lightning-input')) {
                    // Sayfayı o kelimenin olduğu HTML elementine kaydırır (Scroll)
                    node.parentElement.scrollIntoView({
                        behavior: 'smooth',
                        block: 'center'
                    });
                    
                    found = true;
                    break; // İlk eşleşen yere odaklanıp aramayı durdurur
                }
            }

            if (!found) {
                console.log('The searched word was not found on the page.');
            }
        }
    }
}