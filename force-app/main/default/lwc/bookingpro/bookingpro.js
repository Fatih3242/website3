import { LightningElement, track } from 'lwc';
import getAvailableDatesAndHours from '@salesforce/apex/BookingProController.getAvailableDatesAndHours';
import saveBooking from '@salesforce/apex/BookingProController.saveBooking';

export default class Bookingpro extends LightningElement {

    currentStep = 1;

    // Form veri değişkenleri
    @track fullName = '';
    @track companyName = '';
    @track email = '';
    @track phone = '';
    @track selectedBusinessSize = '';
    @track selectedUsers = '';
    @track selectedCRM = '';
    @track selectedFeatures = [];
    @track selectedDay = '';
    @track selectedHour = '';
    @track termsAccepted = false;
    @track marketingConsent = false;
    @track consultationConfirmed = false;

    // Dinamik veri haritası ve başarı durum değişkeni
    allDataMap = {}; 
    @track dayValues = [];
    @track hourValues = [];
    @track isSubmittedSuccessfully = false; // Kayıt başarılı olunca true olacak

    // Sayfa açıldığında verileri çeken fonksiyon
    connectedCallback() {
        getAvailableDatesAndHours()
            .then(result => {
                this.allDataMap = result;
                this.dayValues = Object.keys(result).map(day => {
                    return { label: day, value: day, disabled: false };
                });
            })
            .catch(error => {
                console.error('Data load error: ', error);
            });
    }

    async handleSubmit() {
        console.log('Submit triggered');
        const finalDay = this.selectedDay ? this.selectedDay : 'No Available Date';
        const finalHour = this.selectedHour ? this.selectedHour : 'Call Customer';

        try {
            await saveBooking({
                fullName: this.fullName,
                companyName: this.companyName,
                email: this.email,
                phone: this.phone,
                businessSize: this.selectedBusinessSize,
                users: this.selectedUsers,
                crm: this.selectedCRM,
                features: this.selectedFeaturesText,
                selectedDay: finalDay,
                selectedHour: finalHour,
                marketingConsent: this.marketingConsent
            });
            
            // Sadece kayıt gerçekten başarılı olursa başarı ekranı açılsın
            this.isSubmittedSuccessfully = true;
            this.termsAccepted = false;
            this.consultationConfirmed = true;

        } catch (error) {
            console.error('Salesforce save error: ', error);
            // 🚨 Hatalı durumda başarı ekranını açmak yerine GERÇEK HATAYI ekrana basıyoruz:
            const errorMessage = error.body ? error.body.message : error.message;
            alert('Salesforce Hata Mesajı: ' + errorMessage);
        }
    }

    consultationConfirmed = false;
    get confirmButtonLabel() {

            return this.consultationConfirmed
                ? 'Consultation Request Submitted'
                : 'Confirm Consultation';

    }

    handleTermsConsent(event) {
        this.termsAccepted = event.target.checked;
    }

    // Butonun kilitlenmesini engellemek için her zaman tıklanabilir yapıyoruz
    get disableSubmit() {
        return false; 
    }

    handleMarketingConsent(event) {
        this.marketingConsent = event.target.checked;
    }

    businessSizeValues = ['Just Me', '2 - 5 Employees', '5 - 20 Employees', '20+ Employees'];
    userValues = ['1 User', '2 - 5 Users', '5 - 10 Users', '10+ Users'];
    crmValues = ['No CRM', 'Excel Only', 'Salesforce', 'HubSpot', 'Other CRM'];
    featureValues = ['Email Campaigns', 'SMS Notifications', 'Sales Reporting', 'Customer Tracking', 'Website Lead Forms', 'Customer Portal', 'WhatsApp Integration'];

    /* STEP GETTERS */
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isStep5() { return this.currentStep === 5; }
    get isStep6() { return this.currentStep === 6; }

    /* STEP BAR CLASSES */
    get step1Class() { return this.currentStep >= 1 ? 'step active' : 'step'; }
    get step2Class() { return this.currentStep >= 2 ? 'step active' : 'step'; }
    get step3Class() { return this.currentStep >= 3 ? 'step active' : 'step'; }
    get step4Class() { return this.currentStep >= 4 ? 'step active' : 'step'; }
    get step5Class() { return this.currentStep >= 5 ? 'step active' : 'step'; }
    get step6Class() { return this.currentStep >= 6 ? 'step active' : 'step'; }

    /* DYNAMIC CARD MAPS */
    get businessSizes() {
        return this.businessSizeValues.map(item => {
            return { label:item, value:item, className: this.selectedBusinessSize === item ? 'option-card selected' : 'option-card' };
        });
    }

    get userOptions() {
        return this.userValues.map(item => {
            return { label:item, value:item, className: this.selectedUsers === item ? 'option-card selected' : 'option-card' };
        });
    }

    get crmOptions() {
        return this.crmValues.map(item => {
            return { label:item, value:item, className: this.selectedCRM === item ? 'option-card selected' : 'option-card' };
        });
    }

    get features() {
        return this.featureValues.map(item => {
            return { label:item, value:item, className: this.selectedFeatures.includes(item) ? 'feature-card selected' : 'feature-card' };
        });
    }

    get days() {
        return this.dayValues.map(item => {
            let className = 'day-card';
            if(item.disabled) { className = 'day-card disabled'; }
            else if(this.selectedDay === item.value) { className = 'day-card active'; }
            return { ...item, className };
        });
    }

    get hours() {
        return this.hourValues.map(item => {
            return { label:item, value:item, className: this.selectedHour === item ? 'hour-card active' : 'hour-card' };
        });
    }

    get selectedFeaturesText() {
        return this.selectedFeatures.join(', ');
    }

    /* NAVIGATION EVENTS */
    goToStep(event) {
        const targetStep = Number(event.currentTarget.dataset.step);

        // Eğer kullanıcı henüz 1. adımdaysa ve üst barda başka bir numaraya (2,3,4,5,6) tıklayarak kaçmaya çalışıyoralarsa kontrol et
        if (this.currentStep === 1 && targetStep > 1) {
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            
            // E-posta boşsa veya hatalıysa başka adıma geçişi engelle ve hata balonunu göster
            if (!this.email || !emailRegex.test(this.email)) {
                const emailInput = this.template.querySelector('[data-id="emailField"]');
                if (emailInput) {
                    emailInput.setCustomValidity("Please enter a valid email address.");
                    emailInput.reportValidity();
                }
                return; // Fonksiyonu durdur, üst numaraya geçişi iptal et
            } else {
                // Mail doğruysa eski hatayı temizle
                const emailInput = this.template.querySelector('[data-id="emailField"]');
                if (emailInput) {
                    emailInput.setCustomValidity("");
                    emailInput.reportValidity();
                }
            }
        }

        // Eğer e-posta kontrolünden geçtiyse veya zaten Step 1 dışındaysa tıklanan adıma normal şekilde git
        this.currentStep = targetStep;
    }
    
    handleNext() {
        // Eğer kullanıcı 1. adımdaysa e-postayı kontrol et
        if (this.currentStep === 1) {
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            
            // E-posta boşsa veya hatalıysa Step 2'ye geçişi engelle
            if (!this.email || !emailRegex.test(this.email)) {
                const emailInput = this.template.querySelector('[data-id="emailField"]');
                if (emailInput) {
                    // Tarayıcının kendi yerel "Geçerli bir e-posta adresi girin" uyarısını tetikler
                    emailInput.setCustomValidity("Please enter a valid email address.");
                    emailInput.reportValidity();
                }
                return; // Step 2'ye geçişi durdurur
            } else {
                // Eğer mail doğruysa eski kalmış olabilecek hata uyarısını temizle
                const emailInput = this.template.querySelector('[data-id="emailField"]');
                if (emailInput) {
                    emailInput.setCustomValidity("");
                    emailInput.reportValidity();
                }
            }
        }

        // Kontrolden geçtiyse normal şekilde sonraki adıma ilerle
        if (this.currentStep < 6) {
            this.currentStep++;
        }
    }

    handlePrevious() { if(this.currentStep > 1) { this.currentStep--; } }

    /* DATA HANDLERS */
    handleBusinessSize(event) { this.selectedBusinessSize = event.currentTarget.dataset.value; }
    handleUsers(event) { this.selectedUsers = event.currentTarget.dataset.value; }
    handleCRM(event) { this.selectedCRM = event.currentTarget.dataset.value; }
    handleFeature(event) {
        const value = event.currentTarget.dataset.value;
        if(this.selectedFeatures.includes(value)) {
            this.selectedFeatures = this.selectedFeatures.filter(item => item !== value);
        } else {
            this.selectedFeatures = [...this.selectedFeatures, value];
        }
    }
    handleDay(event) {
        this.selectedDay = event.currentTarget.dataset.value;
        this.selectedHour = ''; 
        this.hourValues = this.allDataMap[this.selectedDay] || [];
    }
    handleHour(event) { this.selectedHour = event.currentTarget.dataset.value; }
    handleFullName(event) { this.fullName = event.target.value; }
    handleCompanyName(event) { this.companyName = event.target.value; }
    handleEmail(event) { this.email = event.target.value; }
    handlePhone(event) { this.phone = event.target.value; }
}