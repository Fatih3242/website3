/**
 * EXECUTE ANONYMOUS SCRIPT FOR VegvesenPointSyncQueueable
 * 
 * PURPOSE: Test and run the static traffic registration point sync from Vegvesen API
 * 
 * PREREQUISITES (MUST BE COMPLETED FIRST):
 * 
 * 1. Remote Site Settings:
 *    - Navigate to: Setup > Security > Remote Site Settings
 *    - Click "New Remote Site"
 *    - Remote Site Name: Vegvesen_Trafikkdata
 *    - Remote Site URL: https://www.vegvesen.no
 *    - Active: Checked
 *    - Description: Norwegian Public Roads Administration Traffic Data API
 *    - Click "Save"
 * 
 * 2. Verify Traffic_Data__c Custom Object exists with required fields:
 *    - Name (Text - Auto Number or Text, External ID)
 *    - Location_Name__c (Text, 255)
 *    - Image_Url__c (Long Text Area, 131,072)
 *    - Location__c (Geolocation)
 *      * Location__Latitude__s (auto-created)
 *      * Location__Longitude__s (auto-created)
 *    - Status__c (Text or Picklist)
 * 
 * USAGE INSTRUCTIONS:
 * 
 * Option 1: Initial Test Run (Debug Logs Enabled)
 *    - Copy lines 42-47 below
 *    - Open Developer Console > Debug > Open Execute Anonymous Window
 *    - Paste and execute
 *    - Check debug logs for detailed execution info
 * 
 * Option 2: Check Job Status
 *    - Copy lines 53-58 below
 *    - Execute to see running/completed async jobs
 * 
 * Option 3: Production Deployment (Via Scheduler)
 *    - Use VegvesenPointSyncScheduler class (to be created)
 *    - Schedule for weekly updates (e.g., Sunday at 2 AM)
 */

// ============================================================================
// OPTION 1: EXECUTE THE SYNC JOB
// ============================================================================

System.debug('=== STARTING VEGVESEN POINT SYNC ===');
Id jobId = System.enqueueJob(new VegvesenPointSyncQueueable());
System.debug('Job enqueued successfully. Job ID: ' + jobId);
System.debug('Monitor progress in: Setup > Environments > Jobs > Apex Jobs');
System.debug('Or query: SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedDate FROM AsyncApexJob WHERE Id = \'' + jobId + '\'');

// ============================================================================
// OPTION 2: CHECK JOB STATUS
// ============================================================================

List<AsyncApexJob> jobs = [
    SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, 
           CreatedDate, CompletedDate, ExtendedStatus, ApexClass.Name
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'VegvesenPointSyncQueueable'
    ORDER BY CreatedDate DESC 
    LIMIT 5
];

System.debug('=== RECENT VEGVESEN SYNC JOBS ===');
for (AsyncApexJob job : jobs) {
    System.debug('Job ID: ' + job.Id);
    System.debug('Status: ' + job.Status);
    System.debug('Created: ' + job.CreatedDate);
    System.debug('Completed: ' + job.CompletedDate);
    System.debug('Errors: ' + job.NumberOfErrors);
    System.debug('Extended Status: ' + job.ExtendedStatus);
    System.debug('---');
}

// ============================================================================
// OPTION 3: VERIFY IMPORTED DATA
// ============================================================================

// Check how many records were imported
Integer recordCount = [SELECT COUNT() FROM Traffic_Data__c WHERE Status__c = 'ACTIVE'];
System.debug('=== DATA VERIFICATION ===');
System.debug('Total active traffic points: ' + recordCount);

// Show sample records
List<Traffic_Data__c> samples = [
    SELECT Name, Location_Name__c, Location__Latitude__s, Location__Longitude__s, 
           Status__c, CreatedDate, LastModifiedDate
    FROM Traffic_Data__c 
    WHERE Status__c = 'ACTIVE'
    ORDER BY CreatedDate DESC 
    LIMIT 5
];

System.debug('=== SAMPLE RECORDS (MOST RECENT) ===');
for (Traffic_Data__c td : samples) {
    System.debug('ID: ' + td.Name + ' | Name: ' + td.Location_Name__c);
    System.debug('Location: ' + td.Location__Latitude__s + ', ' + td.Location__Longitude__s);
    System.debug('Created: ' + td.CreatedDate + ' | Modified: ' + td.LastModifiedDate);
    System.debug('---');
}

// ============================================================================
// OPTION 4: CLEAN UP TEST DATA (USE WITH CAUTION!)
// ============================================================================

// UNCOMMENT ONLY IF YOU NEED TO DELETE ALL TRAFFIC DATA FOR TESTING
// WARNING: This will permanently delete all Traffic_Data__c records!

/*
System.debug('=== DELETING ALL TRAFFIC DATA ===');
List<Traffic_Data__c> allRecords = [SELECT Id FROM Traffic_Data__c LIMIT 10000];
System.debug('Found ' + allRecords.size() + ' records to delete');

if (!allRecords.isEmpty()) {
    Database.DeleteResult[] results = Database.delete(allRecords, false);
    Integer successCount = 0;
    Integer failCount = 0;
    
    for (Database.DeleteResult result : results) {
        if (result.isSuccess()) {
            successCount++;
        } else {
            failCount++;
        }
    }
    
    System.debug('Deletion complete. Success: ' + successCount + ', Failed: ' + failCount);
} else {
    System.debug('No records to delete');
}
*/

// ============================================================================
// TROUBLESHOOTING GUIDE
// ============================================================================

/*
COMMON ISSUES AND SOLUTIONS:

1. Error: "Unauthorized endpoint"
   Solution: Add https://www.vegvesen.no to Remote Site Settings
   
2. Error: "Field does not exist: Location__Latitude__s"
   Solution: Create Geolocation field named Location__c on Traffic_Data__c
   
3. Error: "duplicate value found: Name duplicates value on record"
   Solution: Ensure Name field is set as External ID or unique
   
4. HTTP 405 Method Not Allowed
   Solution: GraphQL endpoint requires POST method (already implemented)
   
5. No records imported (Status: Completed, but 0 records)
   Solution: Check debug logs for GraphQL errors or JSON parsing issues
   
6. Timeout errors
   Solution: Increase timeout (currently 120 seconds) or filter by region
   
7. Governor limit issues
   Solution: Class uses Database.upsert with allOrNone=false for partial success

MONITORING:

- Setup > Environments > Jobs > Apex Jobs
- Developer Console > Logs > Debug Logs
- Setup > Environments > Jobs > Apex Flex Queue
- Query: SELECT Id, Status, ApexClass.Name FROM AsyncApexJob WHERE JobType = 'Queueable'

PERFORMANCE TIPS:

- Initial sync may take 2-5 minutes depending on data volume
- Subsequent runs are faster due to upsert operation
- Class is bulk-safe and handles 10,000+ records
- Each record includes full JSON in Image_Url__c for debugging
*/

// ============================================================================
// NEXT STEPS
// ============================================================================

/*
After successful static point sync:

1. Create VegvesenVolumeDataQueueable class for hourly traffic volume updates
2. Create scheduler classes:
   - VegvesenPointSyncScheduler (weekly - Sunday 2 AM)
   - VegvesenVolumeDataScheduler (hourly)
3. Set up monitoring and alerting for failed jobs
4. Consider adding custom notification on sync completion
5. Build Lightning Web Component for visualization
*/