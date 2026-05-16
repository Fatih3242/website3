/**
 * @description       : 
 * @author            : Fatih SARI
 * @group             : 
 * @last modified on  : 05-16-2026
 * @last modified by  : Fatih SARI
**/
@isTest
private class SupportPageController_Test {

    @isTest
    static void testSaveSupportRequestSuccess() {
        Test.startTest();
        SupportPageController.saveSupportRequest(
            'Fatih Sarı', 'fatih@test.com', 'CRM Pro',
            'Technical Issue', 'Açıklama mesajı.', 'High', true
        );
        Test.stopTest();

        // 🟩 DOĞRULAMA (Dinamik SOQL ve SObject Mimarisi):
        // Derleyicinin katı alan denetimine takılmamak için sorguyu generic SObject listesi olarak çekiyoruz
        List<SObject> results = Database.query('SELECT Id, Name FROM Support_Request__c');
        
        // 1. Kayıt veritabanına başarıyla eklendi mi?
        System.assertEquals(1, results.size(), 'Kayıt başarıyla atılmalıydı.');
        
        // 2. Zorunlu Name alanı dinamik olarak doğru atandı mı?
        SObject record = results[0];
        System.assertEquals('Fatih Sarı', (String)record.get('Name'), 'Müşteri ismi doğrudan zorunlu Name alanına yazılmalıydı.');
    }
}