/**
 * @description       : 
 * @author            : Fatih SARI
 * @group             : 
 * @last modified on  : 05-16-2026
 * @last modified by  : Fatih SARI
**/
public without sharing class SupportPageController {
    
    

    @AuraEnabled
    public static void saveSupportRequest(String fullName, String email, String company, 
                                          String category, String message, String priority, 
                                          Boolean marketingConsent) {
        try {
            Support_Request__c newRequest = new Support_Request__c();
            
            // LWC JS'ten gelen verilerin custom alanlara doğrudan insert edilmesi
            newRequest.Full_Name__c = fullName;
            newRequest.Email__c = email;
            newRequest.Company_Name__c = company;
            newRequest.Category__c = category;
            newRequest.Message__c = message;
            newRequest.Priority__c = priority;
            newRequest.Subscription__c = marketingConsent;
            newRequest.Name = 'Online Support Request';
            // Veritabanına doğrudan insert işlemi
            insert newRequest;
            
        } catch (Exception e) {
            throw new AuraHandledException('Database insert error: ' + e.getMessage());
        }
    }
}