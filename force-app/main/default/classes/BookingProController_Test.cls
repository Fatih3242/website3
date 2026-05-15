/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class BookingProController_Test {

    // Test verilerini hazırlayan metot
    @TestSetup
    static void makeData(){
        // 1. Bir adet müsaitlik zaman penceresi oluşturalım: Bugünden sonraki ilk güne randevu penceresi aç
        Availability_Window__c window = new Availability_Window__c();
        window.Date__c = Date.today().addDays(1);
        window.Start_Time__c = Time.newInstance(8, 30, 0, 0); // 08:30
        window.End_Time__c = Time.newInstance(11, 0, 0, 0);   // 11:00 (İçinden 09:00 ve 10:00 slotları çıkmalı)
        insert window;

        // 2. Bir adet de halihazırda rezerve edilmiş slot oluşturalım (Çakışma mekanizmasını test etmek için)
        // Yarının tarihi için "dd MMM" formatını hesaplayalım (Örn: "16 May")
        String dateLabel = DateTime.newInstance(Date.today().addDays(1), Time.newInstance(0,0,0,0)).format('dd MMM');
        
        Booking__c existingBooking = new Booking__c();
        existingBooking.Full_Name__c = 'Mevcut Müşteri';
        existingBooking.Booking_Date__c = Date.today().addDays(1);
        existingBooking.Booking_Hour__c = '10:00'; // 10:00 slotunu rezerve ettik
        existingBooking.Unique_Slot_Key__c = String.valueOf(Date.today().addDays(1)) + '_10:00';
        insert existingBooking;
    }

    // 1. Dinamik slot hesaplama metodunu test eden senaryo
    @isTest
    static void testGetAvailableDatesAndHours() {
        Test.startTest();
        Map<String, List<String>> result = BookingProController.getAvailableDatesAndHours();
        Test.stopTest();

        // Yarının tarih label'ını bulalım
        String tomorrowLabel = DateTime.newInstance(Date.today().addDays(1), Time.newInstance(0,0,0,0)).format('dd MMM');

        // Doğrulama (Assertions)
        System.assertNotEquals(null, result, 'Dönen harita boş olmamalıdır.');
        System.assert(result.containsKey(tomorrowLabel), 'Harita yarının tarihini içermelidir.');
        
        List<String> hours = result.get(tomorrowLabel);
        // 08:30 girdik -> 09:00 tam saatine yuvarlandı. 10:00 zaten rezerve edilmişti. Sadece "09:00" kalmalı.
        System.assertEquals(1, hours.size(), 'Sadece 1 adet müsait saat kalmış olmalı.');
        System.assertEquals('09:00', hours[0], 'Müsait saat 09:00 olmalıdır.');
    }

    // 2. Başarılı randevu kaydı senaryosu
    @isTest
    static void testSaveBookingSuccess() {
        // Yarının tarih string'ini hazırla (Örn: "16 May")
        String tomorrowLabel = DateTime.newInstance(Date.today().addDays(1), Time.newInstance(0,0,0,0)).format('dd MMM');

        Test.startTest();
        BookingProController.saveBooking(
            'Ahmet Yılmaz', 'Test A.Ş.', 'ahmet@test.com', '5551234567',
            '2 - 5 Employees', '2 - 5 Users', 'No CRM', 'Email Campaigns',
            tomorrowLabel, '09:00', true
        );
        Test.stopTest();

        // Veritabanına gerçekten kaydedildi mi doğrula
        List<Booking__c> bookings = [SELECT Id, Full_Name__c FROM Booking__c WHERE Booking_Hour__c = '09:00'];
        System.assertEquals(1, bookings.size(), 'Yeni booking kaydı başarıyla oluşturulmalıydı.');
        System.assertEquals('Ahmet Yılmaz', bookings[0].Full_Name__c);
    }

    // 3. Aynı saat dilimine mükerrer randevu hatası senaryosu (Hata Yakalama)
    @isTest
    static void testSaveBookingDuplicateError() {
        String tomorrowLabel = DateTime.newInstance(Date.today().addDays(1), Time.newInstance(0,0,0,0)).format('dd MMM');
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            // @TestSetup içinde '10:00' saatini zaten kaydetmiştik. Tekrar kaydetmeyi deniyoruz:
            BookingProController.saveBooking(
                'Mehmet Öz', 'Deneme Ltd.', 'mehmet@deneme.com', '5559876543',
                'Just Me', '1 User', 'Excel Only', 'WhatsApp Integration',
                tomorrowLabel, '10:00', true
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('randevu saati az önce kapıldı'), 'Beklenen hata mesajı fırlatılmadı.');
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Aynı saate ikinci randevu istenirken sistem hata fırlatmalıydı.');
    }
}