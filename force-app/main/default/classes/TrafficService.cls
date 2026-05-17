/**
 * @description       : Statens Vegvesen Canlı Trafik Entegrasyonu (Kesin Lokasyon Sürümü)
 * @author            : Fatih SARI
**/
public with sharing class TrafficService {

    @AuraEnabled
    public static List<Traffic_Data__c> fetchTrafficData() {
        Http http = new Http();
        HttpRequest req = new HttpRequest();

        // Named Credential üzerinden güvenli ve yönlendirmesiz bağlantı
        req.setEndpoint('callout:VegvesenTrafficAPI'); 
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setHeader('User-Agent', 'Mozilla/5.0');

        // KESİN ÇÖZÜM: Şema doğrulama hatasını kökten bitiren, Vegvesen'in en hafif ve saf koordinat sorgusu
        Map<String, Object> requestBodyMap = new Map<String, Object>();
        requestBodyMap.put('query', '{ trafficRegistrationPoints(searchQuery: { roadCategoryIds: [E] }) { id name location { coordinates { latLon { lat lon } } } } }');
        
        req.setBody(JSON.serialize(requestBodyMap));

        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Vegvesen Canlı API Hatası! Kod: ' + res.getStatusCode());
        }

        List<Traffic_Data__c> records = new List<Traffic_Data__c>();
        Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        
        // Sunucu hata dizisi fırlatırsa LWC'ye aktarma katmanı
        if (jsonResponse.containsKey('errors')) {
            List<Object> errorsList = (List<Object>) jsonResponse.get('errors');
            Map<String, Object> firstError = (Map<String, Object>) errorsList[0];
            throw new AuraHandledException('Vegvesen Şema Doğrulama Hatası: ' + (String) firstError.get('message'));
        }

        if (!jsonResponse.containsKey('data')) return records;
        Map<String, Object> data = (Map<String, Object>) jsonResponse.get('data');
        if (data == null || !data.containsKey('trafficRegistrationPoints')) return records;
        
        List<Object> points = (List<Object>) data.get('trafficRegistrationPoints');
        if (points == null) return records;

        Integer counter = 0;
        for (Object obj : points) {
            if(counter >= 60) break; // Harita performans kısıtlaması sınırı
            
            Map<String, Object> item = (Map<String, Object>) obj;
            String locationName = (String) item.get('name');

            Map<String, Object> location = (Map<String, Object>) item.get('location');
            if (location == null) continue;

            Map<String, Object> coordinates = (Map<String, Object>) location.get('coordinates');
            if (coordinates == null) continue;

            Map<String, Object> latLon = (Map<String, Object>) coordinates.get('latLon');
            if (latLon == null || latLon.get('lat') == null || latLon.get('lon') == null) continue;

            // Orijinal WGS84 koordinatlarını Decimal sayı tiplerine dönüştürüyoruz
            Decimal lat = Decimal.valueOf(String.valueOf(latLon.get('lat')));
            Decimal lon = Decimal.valueOf(String.valueOf(latLon.get('lon')));

            Traffic_Data__c record = new Traffic_Data__c();
            record.Name = 'Trafik - ' + locationName;
            record.Location_Name__c = locationName;
            record.Latitude__c = lat;
            record.Longitude__c = lon;
            record.Congestion_Level__c = 0; 
            record.Status__c = 'Aktif İstasyon (Sensör Çevrimiçi)';

            records.add(record);
            counter++;
        }

        return records;
    }
}