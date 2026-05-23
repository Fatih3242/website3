/**
 * @description       : Production-ready Queueable class for syncing static traffic registration points 
 *                      from Norwegian Vegvesen GraphQL API to Traffic_Data__c custom object
 * @author            : Fatih SARI
 * @group             : Integration
 * @last modified on  : 05-23-2026
 * @last modified by  : Fatih SARI
 * 
 * PREREQUISITES:
 * - Remote Site Settings must include: https://api.vegvesen.no OR use Named Credential
 * - Traffic_Data__c custom object with fields:
 *   * Name (Text, unique identifier)
 *   * Location_Name__c (Text)
 *   * Image_Url__c (Long Text Area - stores full JSON)
 *   * Location__c (Geolocation)
 *   * Status__c (Text/Picklist)
 * 
 * USAGE:
 * System.enqueueJob(new VegvesenPointSyncQueueable());
 */
public without sharing class VegvesenPointSyncQueueable implements Queueable, Database.AllowsCallouts {
    
    // Constants
    // Correct GraphQL API endpoint for Vegvesen traffic data
    // NOTE: You need to add https://trafikkdata-api.atlas.vegvesen.no to Remote Site Settings
    // OR create a Named Credential named 'Vegvesen' with URL: https://trafikkdata-api.atlas.vegvesen.no
    private static final String ENDPOINT_URL = 'https://trafikkdata-api.atlas.vegvesen.no';
    // Use a minimal query without the countyIds filter to avoid schema validation errors.
    // We remove the searchQuery argument for now (safe fallback). If you later provide the
    // exact input type from introspection, we can reintroduce a typed variable.
    private static final String GRAPHQL_QUERY = 
        'query { ' +
        '  trafficRegistrationPoints { ' +
        '    id ' +
        '    name ' +
        '    location { ' +
        '      coordinates { ' +
        '        latLon { ' +
        '          lat ' +
        '          lon ' +
        '        } ' +
        '      } ' +
        '    } ' +
        '  } ' +
        '}';
    
    // Safety: limit number of points processed per Queueable invocation to avoid Apex CPU limit
    private static final Integer MAX_BATCH_SIZE = 200;
    
    // Optional continuation token / offset when chaining Queueables
    // The API currently doesn't provide an offset; we use an index offset into the returned list
    private Integer startIndex = 0;
    
    // Constructor allowing chaining with an index offset
    public VegvesenPointSyncQueueable() { }
    
    public VegvesenPointSyncQueueable(Integer startIndex) {
        this.startIndex = startIndex;
    }
    
    /**
     * @description Main execution method called by Queueable framework
     * @param context QueueableContext provided by platform
     */
    public void execute(QueueableContext context) {
        System.debug('VegvesenPointSyncQueueable: Starting execution');
        
        try {
            // Step 1: Make HTTP callout to Vegvesen GraphQL API
            HttpResponse response = makeGraphQLCallout();
            
            // Step 2: Validate response
            if (!isValidResponse(response)) {
                System.debug(LoggingLevel.ERROR, 
                    'VegvesenPointSyncQueueable: Invalid response received. Status: ' + 
                    response.getStatusCode() + ', Body: ' + response.getBody());
                return;
            }
            
            // Step 3: Parse JSON response safely
            List<Map<String, Object>> trafficPoints = parseGraphQLResponse(response.getBody());
            
            if (trafficPoints == null || trafficPoints.isEmpty()) {
                System.debug('VegvesenPointSyncQueueable: No traffic points found in response');
                return;
            }
            
            System.debug('VegvesenPointSyncQueueable: Found ' + trafficPoints.size() + ' traffic points');
            
            // Step 4: Transform to Salesforce records
            List<Traffic_Data__c> trafficDataRecords = transformToSalesforceRecords(trafficPoints);
            
            // Step 5: Upsert records (using Name as external ID for idempotency)
            upsertTrafficData(trafficDataRecords);
            
            System.debug('VegvesenPointSyncQueueable: Execution completed successfully');
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 
                'VegvesenPointSyncQueueable: Fatal error during execution: ' + 
                e.getMessage() + '\n' + e.getStackTraceString());
            // In production, you might want to create an error log record here
        }
    }
    
    /**
     * @description Makes HTTP POST request to Vegvesen GraphQL API
     * Note: Vegvesen API requires POST method with JSON body containing query
     * @return HttpResponse from the API
     */
    private HttpResponse makeGraphQLCallout() {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        
        // Build GraphQL request body as JSON
        Map<String, Object> requestBody = new Map<String, Object>{
            'query' => GRAPHQL_QUERY,
            'variables' => null
        };
        
        String jsonBody = JSON.serialize(requestBody);
        
        req.setEndpoint(ENDPOINT_URL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(jsonBody);
        req.setTimeout(120000); // 120 seconds timeout
        
        System.debug('VegvesenPointSyncQueueable: Sending POST request to ' + ENDPOINT_URL);
        System.debug('VegvesenPointSyncQueueable: Request body: ' + jsonBody);
        
        HttpResponse response = http.send(req);
        
        System.debug('VegvesenPointSyncQueueable: Response status: ' + response.getStatusCode());
        System.debug('VegvesenPointSyncQueueable: Content-Type response: ' + response.getHeader('Content-Type'));
        
        if (response.getStatusCode() == 200) {
            System.debug('VegvesenPointSyncQueueable: SUCCESS! Response body length: ' + 
                (response.getBody() != null ? response.getBody().length() : 0));
        } else {
            System.debug(LoggingLevel.ERROR, 'VegvesenPointSyncQueueable: Error status: ' + response.getStatusCode());
            System.debug(LoggingLevel.ERROR, 'Response body: ' + response.getBody());
        }
        
        return response;
    }
    
    /**
     * @description Validates HTTP response status and body
     * @param response HttpResponse to validate
     * @return Boolean indicating if response is valid
     */
    private Boolean isValidResponse(HttpResponse response) {
        if (response == null) {
            System.debug(LoggingLevel.ERROR, 'VegvesenPointSyncQueueable: Response is null');
            return false;
        }
        
        if (response.getStatusCode() != 200) {
            System.debug(LoggingLevel.ERROR, 
                'VegvesenPointSyncQueueable: Non-200 status code: ' + response.getStatusCode());
            return false;
        }
        
        String body = response.getBody();
        if (String.isBlank(body)) {
            System.debug(LoggingLevel.ERROR, 'VegvesenPointSyncQueueable: Response body is empty');
            return false;
        }
        
        return true;
    }
    
    /**
     * @description Parses GraphQL JSON response and extracts traffic registration points
     * @param responseBody JSON string from API response
     * @return List of traffic point maps, or empty list if parsing fails
     */
    private List<Map<String, Object>> parseGraphQLResponse(String responseBody) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        
        try {
            // Parse root JSON
            Map<String, Object> rootMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            
            if (rootMap == null) {
                System.debug(LoggingLevel.ERROR, 'VegvesenPointSyncQueueable: Root map is null');
                return result;
            }
            
            // Check for GraphQL errors
            if (rootMap.containsKey('errors')) {
                List<Object> errors = (List<Object>) rootMap.get('errors');
                System.debug(LoggingLevel.ERROR, 
                    'VegvesenPointSyncQueueable: GraphQL errors detected: ' + JSON.serialize(errors));
                return result;
            }
            
            // Navigate to data.trafficRegistrationPoints
            Map<String, Object> dataMap = (Map<String, Object>) rootMap.get('data');
            if (dataMap == null) {
                System.debug(LoggingLevel.ERROR, 'VegvesenPointSyncQueueable: data node is null');
                return result;
            }
            
            List<Object> pointsList = (List<Object>) dataMap.get('trafficRegistrationPoints');
            if (pointsList == null || pointsList.isEmpty()) {
                System.debug('VegvesenPointSyncQueueable: trafficRegistrationPoints is null or empty');
                return result;
            }
            
            // Convert to typed list
            for (Object pointObj : pointsList) {
                if (pointObj instanceof Map<String, Object>) {
                    result.add((Map<String, Object>) pointObj);
                }
            }
            
            // If the API returned a very large list, we will not process all records in one transaction.
            // Upstream logic will slice the list at transformToSalesforceRecords stage to respect MAX_BATCH_SIZE.
            System.debug('VegvesenPointSyncQueueable: Parsed ' + result.size() + ' points from response (will process up to ' + MAX_BATCH_SIZE + ' per job).');
            
        } catch (JSONException e) {
            System.debug(LoggingLevel.ERROR, 
                'VegvesenPointSyncQueueable: JSON parsing error: ' + e.getMessage());
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 
                'VegvesenPointSyncQueueable: Unexpected parsing error: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * @description Transforms API response maps to Traffic_Data__c records
     * @param trafficPoints List of traffic point maps from API
     * @return List of Traffic_Data__c records ready for DML
     */
    private List<Traffic_Data__c> transformToSalesforceRecords(List<Map<String, Object>> trafficPoints) {
        List<Traffic_Data__c> records = new List<Traffic_Data__c>();
        Integer successCount = 0;
        Integer skipCount = 0;
        
        // Process only a slice of the list to avoid CPU limit
        Integer endIndex = Math.min(startIndex + MAX_BATCH_SIZE, trafficPoints.size());
        if (startIndex >= endIndex) {
            System.debug('VegvesenPointSyncQueueable: startIndex >= endIndex, nothing to process. startIndex=' + startIndex + ' endIndex=' + endIndex);
            return records;
        }
        
        for (Integer i = startIndex; i < endIndex; i++) {
            Map<String, Object> point = trafficPoints[i];
            try {
                Traffic_Data__c record = createTrafficDataRecord(point);
                
                if (record != null) {
                    records.add(record);
                    successCount++;
                } else {
                    skipCount++;
                }
                
            } catch (Exception e) {
                skipCount++;
                // Reduced logging to minimize CPU overhead: log summary info only
                System.debug(LoggingLevel.WARN, 
                    'VegvesenPointSyncQueueable: Skipping point at index ' + i + ' due to error: ' + e.getMessage());
            }
        }
        
        // If there are more records left unprocessed, enqueue a chained job to continue processing
        if (endIndex < trafficPoints.size()) {
            Integer nextStart = endIndex;
            System.debug('VegvesenPointSyncQueueable: Processed slice up to index ' + endIndex + '. Enqueuing next job starting at ' + nextStart);
            System.enqueueJob(new VegvesenPointSyncQueueable(nextStart));
        }
        
        System.debug('VegvesenPointSyncQueueable: Transformed ' + successCount + 
            ' records successfully, skipped ' + skipCount + ' records');
        
        return records;
    }
    
    /**
     * @description Creates a single Traffic_Data__c record from API point data
     * @param point Map containing traffic registration point data
     * @return Traffic_Data__c record, or null if required data is missing
     */
    private Traffic_Data__c createTrafficDataRecord(Map<String, Object> point) {
        // Extract and validate required fields
        String pointId = getStringValue(point, 'id');
        String pointName = getStringValue(point, 'name');
        
        if (String.isBlank(pointId)) {
            System.debug(LoggingLevel.WARN, 'VegvesenPointSyncQueueable: Point missing id field');
            return null;
        }
        
        // Extract coordinates safely
        Map<String, Decimal> coordinates = extractCoordinates(point);
        
        if (coordinates == null) {
            System.debug(LoggingLevel.WARN, 
                'VegvesenPointSyncQueueable: Point ' + pointId + ' missing valid coordinates');
            return null;
        }
        
        // Create Traffic_Data__c record
        Traffic_Data__c record = new Traffic_Data__c();
        record.Name = pointId;
        record.Location_Name__c = String.isNotBlank(pointName) ? pointName : 'Unknown';
        record.Image_Url__c = JSON.serialize(point); // Store full JSON for reference
        record.Location__Latitude__s = coordinates.get('lat');
        record.Location__Longitude__s = coordinates.get('lon');
        record.Status__c = 'ACTIVE';
        
        return record;
    }
    
    /**
     * @description Safely extracts coordinates from nested location structure
     * @param point Map containing traffic registration point data
     * @return Map with 'lat' and 'lon' keys, or null if extraction fails
     */
    private Map<String, Decimal> extractCoordinates(Map<String, Object> point) {
        try {
            // Navigate: location -> coordinates -> latLon -> {lat, lon}
            Map<String, Object> location = (Map<String, Object>) point.get('location');
            if (location == null) return null;
            
            Map<String, Object> coordinates = (Map<String, Object>) location.get('coordinates');
            if (coordinates == null) return null;
            
            Map<String, Object> latLon = (Map<String, Object>) coordinates.get('latLon');
            if (latLon == null) return null;
            
            Object latObj = latLon.get('lat');
            Object lonObj = latLon.get('lon');
            
            if (latObj == null || lonObj == null) return null;
            
            // Convert to Decimal (handles Integer, Double, String)
            Decimal lat = convertToDecimal(latObj);
            Decimal lon = convertToDecimal(lonObj);
            
            if (lat == null || lon == null) return null;
            
            // Basic validation (Norway is roughly 58-71°N, 5-31°E)
            if (lat < 55 || lat > 75 || lon < 0 || lon > 35) {
                System.debug(LoggingLevel.WARN, 
                    'VegvesenPointSyncQueueable: Coordinates out of expected range: lat=' + 
                    lat + ', lon=' + lon);
                return null;
            }
            
            return new Map<String, Decimal>{ 'lat' => lat, 'lon' => lon };
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 
                'VegvesenPointSyncQueueable: Error extracting coordinates: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Converts various numeric types to Decimal
     * @param value Object that might be Integer, Double, Decimal, or String
     * @return Decimal value, or null if conversion fails
     */
    private Decimal convertToDecimal(Object value) {
        if (value == null) return null;
        
        try {
            if (value instanceof Decimal) {
                return (Decimal) value;
            } else if (value instanceof Integer) {
                return Decimal.valueOf((Integer) value);
            } else if (value instanceof Double) {
                return Decimal.valueOf((Double) value);
            } else {
                return Decimal.valueOf(String.valueOf(value));
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 
                'VegvesenPointSyncQueueable: Failed to convert value to Decimal: ' + value);
            return null;
        }
    }
    
    /**
     * @description Safely extracts String value from map
     * @param dataMap Map to extract from
     * @param key Key to look up
     * @return String value, or null if not found or not a string
     */
    private String getStringValue(Map<String, Object> dataMap, String key) {
        if (dataMap == null || !dataMap.containsKey(key)) return null;
        
        Object value = dataMap.get(key);
        return value != null ? String.valueOf(value) : null;
    }
    
    /**
     * @description Performs upsert operation with proper error handling
     * @param records List of Traffic_Data__c records to upsert
     */
    private void upsertTrafficData(List<Traffic_Data__c> records) {
        if (records == null || records.isEmpty()) {
            System.debug('VegvesenPointSyncQueueable: No records to upsert');
            return;
        }
        
        System.debug('VegvesenPointSyncQueueable: Upserting ' + records.size() + ' records');
        
        try {
            // Use Database.upsert with allOrNone=false for partial success
            Database.UpsertResult[] results = Database.upsert(records, 
                Traffic_Data__c.Name, false);
            
            // Log results
            Integer successCount = 0;
            Integer failCount = 0;
            
            for (Integer i = 0; i < results.size(); i++) {
                Database.UpsertResult result = results[i];
                
                if (result.isSuccess()) {
                    successCount++;
                } else {
                    failCount++;
                    Traffic_Data__c failedRecord = records[i];
                    // Reduced per-error string concatenation to a single concise message
                    String errorMsg = 'VegvesenPointSyncQueueable: Failed to upsert record ' + failedRecord.Name;
                    // Log first error message only to avoid expensive loops/serializations
                    if (result.getErrors() != null && result.getErrors().size() > 0) {
                        errorMsg += ': ' + result.getErrors()[0].getMessage();
                    }
                    System.debug(LoggingLevel.ERROR, errorMsg);
                }
            }
            
            System.debug('VegvesenPointSyncQueueable: Upsert completed. Success: ' + 
                successCount + ', Failed: ' + failCount);
            
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 
                'VegvesenPointSyncQueueable: DML Exception during upsert: ' + 
                e.getMessage() + '\n' + e.getStackTraceString());
        }
    }
}
