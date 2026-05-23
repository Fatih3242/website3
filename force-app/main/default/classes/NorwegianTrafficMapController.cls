/**
 * @description       : 
 * @author            : Fatih SARI
 * @group             : 
 * @last modified on  : 05-23-2026
 * @last modified by  : Fatih SARI
**/
public without sharing class NorwegianTrafficMapController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getTrafficData(){

        // Return a lightweight DTO per record with persisted numeric volume and coverage.
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        for (Traffic_Data__c t : [
            SELECT Id, Name, Location_Name__c, Status__c, Image_Url__c,
                   Hourly_Volume__c, Volume_Coverage__c,
                   Location__Latitude__s, Location__Longitude__s
            FROM Traffic_Data__c
            WHERE Status__c = 'ACTIVE'
        ]) {
            Map<String, Object> m = new Map<String, Object>();
            m.put('Id', t.Id);
            m.put('Name', t.Name);
            m.put('Location_Name__c', t.Location_Name__c);
            m.put('Status__c', t.Status__c);
            m.put('Image_Url__c', t.Image_Url__c);
            // Expose numeric volume and coverage with stable keys the LWC expects
            m.put('numericVolume', t.Hourly_Volume__c);
            m.put('coverage', t.Volume_Coverage__c);
            m.put('Location__Latitude__s', t.Location__Latitude__s);
            m.put('Location__Longitude__s', t.Location__Longitude__s);
            out.add(m);
        }

        return out;

    }

}
