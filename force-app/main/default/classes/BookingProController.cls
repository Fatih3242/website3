/**
 * @description       : 
 * @author            : Fatih SARI
 * @group             : 
 * @last modified on  : 05-16-2026
 * @last modified by  : Fatih SARI
**/
public without sharing class BookingProController {

    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getAvailableDatesAndHours() {
        Map<String, List<String>> dateToHoursMap = new Map<String, List<String>>();
        
        Set<String> bookedSlots = new Set<String>();
        for(Booking__c b : [SELECT Booking_Date__c, Booking_Hour__c FROM Booking__c WHERE Booking_Date__c >= :Date.today()]) {
            String dateKey = DateTime.newInstance(b.Booking_Date__c, Time.newInstance(0,0,0,0)).format('dd MMM');
            bookedSlots.add(dateKey + '_' + b.Booking_Hour__c);
        }

        List<Availability_Window__c> windows = [
            SELECT Date__c, Start_Time__c, End_Time__c 
            FROM Availability_Window__c 
            WHERE Date__c >= :Date.today() 
            ORDER BY Date__c ASC
        ];

        for(Availability_Window__c window : windows) {
            String dateLabel = DateTime.newInstance(window.Date__c, Time.newInstance(0,0,0,0)).format('dd MMM');
            
            if(!dateToHoursMap.containsKey(dateLabel)) {
                dateToHoursMap.put(dateLabel, new List<String>());
            }

            Integer startHour = window.Start_Time__c.hour();
            if(window.Start_Time__c.minute() > 0) { startHour += 1; }
            Integer endHour = window.End_Time__c.hour();

            for(Integer h = startHour; h < endHour; h++) {
                String hourString = (h < 10 ? '0' + h : String.valueOf(h)) + ':00';
                if(!bookedSlots.contains(dateLabel + '_' + hourString)) {
                    dateToHoursMap.get(dateLabel).add(hourString);
                }
            }
        }
        return dateToHoursMap;
    }

    @AuraEnabled
    public static void saveBooking(String fullName, String companyName, String email, String phone, 
                                   String businessSize, String users, String crm, String features, 
                                   String selectedDay, String selectedHour, Boolean marketingConsent) {
        try {
            Booking__c newBooking = new Booking__c();
            // ==========================================
            // 🟩 STANDART NAME ALANI ZORUNLULUĞU İÇİN EKLENEN KISIM:
            // Eğer tam isim girildiyse onu, girilmediyse şirket adını, ikisi de yoksa genel bir başlık atar.
            if (String.isNotBlank(fullName)) {
                newBooking.Name = fullName; // Eğer objenizin standart Name alanı text ise burası doldurur
            } else if (String.isNotBlank(companyName)) {
                newBooking.Name = companyName + ' Request';
            } else {
                newBooking.Name = 'Online Consultation Request';
            }
            newBooking.Full_Name__c = fullName;
            newBooking.Company_Name__c = companyName;
            newBooking.Email__c = email;
            newBooking.Phone__c = phone;
            newBooking.Business_Size__c = businessSize;
            newBooking.Selected_Users__c = users;
            newBooking.Selected_CRM__c = crm;
            newBooking.Selected_Features__c = features;
            newBooking.Booking_Hour__c = selectedHour;
            newBooking.Subscription__c = marketingConsent; 
            
            Date parsedDate = null;

            if (selectedDay != 'No Available Date' && String.isNotBlank(selectedDay) && selectedDay.contains(' ')) {
                Integer currentYear = Date.today().year();
                List<String> dayParts = selectedDay.split(' ');
                
                Map<String, Integer> months = new Map<String, Integer>{
                    'Jan'=>1, 'Feb'=>2, 'Mar'=>3, 'Apr'=>4, 'May'=>5, 'Jun'=>6,
                    'Jul'=>7, 'Aug'=>8, 'Sep'=>9, 'Oct'=>10, 'Nov'=>11, 'Dec'=>12
                };
                
                // HATA DÜZELTİLDİ: Liste indeksleri tanımlandı
                Integer dayValue = Integer.valueOf(dayParts[0]);
                String monthStr = dayParts[1];
                Integer monthValue = months.get(monthStr);

                parsedDate = Date.newInstance(currentYear, monthValue, dayValue);
                newBooking.Booking_Date__c = parsedDate;
                newBooking.Unique_Slot_Key__c = String.valueOf(parsedDate) + '_' + selectedHour;
            } else {
                newBooking.Unique_Slot_Key__c = 'NO_SLOT_' + String.valueOf(Crypto.getRandomLong());
            }

            insert newBooking;
        } catch (Exception e) {
            throw new AuraHandledException('Error during save: ' + e.getMessage());
        }
    }
}