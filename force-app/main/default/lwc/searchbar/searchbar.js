import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class CustomSearchBar extends NavigationMixin(LightningElement) {
    @track searchKey = '';

    handleInputChange(event) {
        this.searchKey = event.target.value;
    }

    handleKeyDown(event) {
        // Kullanıcı klavyeden Enter tuşuna bastığında aramayı başlatır
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }

    handleSearch() {
        if (this.searchKey.trim()) {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'Search'
                },
                state: {
                    term: this.searchKey
                }
            });
        }
    }
}