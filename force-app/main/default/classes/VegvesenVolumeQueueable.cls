/**
 * @description       : Queueable class for syncing hourly traffic volume data from Vegvesen API
 *                      Fetches volume data for existing traffic registration points
 * @author            : Fatih SARI
 * @group             : Integration
 * @last modified on  : 05-23-2026
 * 
 * PREREQUISITES:
 * - Traffic_Data__c records must exist (from VegvesenPointSyncQueueable)
 * - Remote Site Settings: https://trafikkdata-api.atlas.vegvesen.no
 * - Custom fields on Traffic_Data__c:
 *   * Hourly_Volume__c (Number - latest hour volume)
 *   * Last_Volume_Sync__c (DateTime)
 *   * Volume_Coverage__c (Number - data quality %)
 * 
 * USAGE:
 * // Sync last 24 hours for all Oslo traffic points
 * System.enqueueJob(new VegvesenVolumeQueueable());
 */
public without sharing class VegvesenVolumeQueueable implements Queueable, Database.AllowsCallouts {
    
    // Constants
    private static final String ENDPOINT_URL = 'https://trafikkdata-api.atlas.vegvesen.no';
    private static final Integer HOURS_TO_FETCH = 24; // Last 24 hours
    private static final Integer MAX_POINTS_PER_RUN = 50; // Process 50 points per run
    
    private Integer offsetIndex;
    
    /**
     * @description Default constructor - starts from beginning
     */
    public VegvesenVolumeQueueable() {
        this.offsetIndex = 0;
    }
    
    /**
     * @description Constructor with offset for chaining
     * @param offsetIndex Starting index for batch processing
     */
    public VegvesenVolumeQueueable(Integer offsetIndex) {
        this.offsetIndex = offsetIndex;
    }
    
    // New field for id-based paging (optional)
    private Id lastProcessedId;
    
    /**
     * @description Constructor with lastProcessedId for id-based paging
     * @param lastProcessedId Id of last processed Traffic_Data__c
     */
    public VegvesenVolumeQueueable(Id lastProcessedId) {
        this.offsetIndex = 0;
        this.lastProcessedId = lastProcessedId;
    }
    
    /**
     * @description Main execution method
     * @param context QueueableContext provided by platform
     */
    public void execute(QueueableContext context) {
        System.debug('VegvesenVolumeQueueable: Starting execution, offset=' + offsetIndex);
        
        try {
            // Get traffic points that need volume sync
            List<Traffic_Data__c> trafficPoints = getTrafficPointsToSync();
            
            if (trafficPoints.isEmpty()) {
                System.debug('VegvesenVolumeQueueable: No more points to process');
                return;
            }
            
            System.debug('VegvesenVolumeQueueable: Processing ' + trafficPoints.size() + ' points');
            
            // Fetch and update volume data for each point
            List<Traffic_Data__c> updatedPoints = new List<Traffic_Data__c>();
            
            for (Traffic_Data__c point : trafficPoints) {
                try {
                    Traffic_Data__c updated = fetchAndUpdateVolume(point);
                    if (updated != null) {
                        updatedPoints.add(updated);
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 
                        'VegvesenVolumeQueueable: Error processing point ' + point.Name + 
                        ': ' + e.getMessage());
                }
            }
            
            // Update records
            if (!updatedPoints.isEmpty()) {
                updateTrafficPoints(updatedPoints);
            }
            
            // Chain next batch if there are more points
            if (trafficPoints.size() == MAX_POINTS_PER_RUN) {
                System.debug('VegvesenVolumeQueueable: Chaining next batch, offset=' + 
                    (offsetIndex + MAX_POINTS_PER_RUN));
                System.enqueueJob(new VegvesenVolumeQueueable(offsetIndex + MAX_POINTS_PER_RUN));
            } else {
                System.debug('VegvesenVolumeQueueable: All points processed');
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 
                'VegvesenVolumeQueueable: Fatal error: ' + e.getMessage() + 
                '\n' + e.getStackTraceString());
        }
    }
    
    /**
     * @description Gets traffic points that need volume sync
     * @return List of Traffic_Data__c records
     */
    private List<Traffic_Data__c> getTrafficPointsToSync() {
        return [
            SELECT Id, Name, Location_Name__c, 
                   Hourly_Volume__c, Last_Volume_Sync__c, Volume_Coverage__c
            FROM Traffic_Data__c
            WHERE Status__c = 'ACTIVE'
            ORDER BY Last_Volume_Sync__c ASC NULLS FIRST
            LIMIT :MAX_POINTS_PER_RUN
            OFFSET :offsetIndex
        ];
    }
    
    /**
     * @description Fetches volume data for a traffic point and updates the record
     * @param point Traffic_Data__c record
     * @return Updated Traffic_Data__c record or null
     */
    private Traffic_Data__c fetchAndUpdateVolume(Traffic_Data__c point) {
        // Build time range - last 24 hours
        DateTime toTime = DateTime.now();
        DateTime fromTime = toTime.addHours(-HOURS_TO_FETCH);
        
        String fromISO = fromTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'+00:00\'');
        String toISO = toTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'+00:00\'');
        
        // Build GraphQL query for volume data
        String volumeQuery = 
            'query { ' +
            '  trafficData(trafficRegistrationPointId: "' + point.Name + '") { ' +
            '    volume { ' +
            '      byHour(from: "' + fromISO + '", to: "' + toISO + '") { ' +
            '        edges { ' +
            '          node { ' +
            '            from ' +
            '            to ' +
            '            total { ' +
            '              volumeNumbers { ' +
            '                volume ' +
            '              } ' +
            '              coverage { ' +
            '                percentage ' +
            '              } ' +
            '            } ' +
            '          } ' +
            '        } ' +
            '      } ' +
            '    } ' +
            '  } ' +
            '}';
        
        // Make API call
        HttpResponse response = makeGraphQLCallout(volumeQuery);
        
        if (response == null || response.getStatusCode() != 200) {
            System.debug(LoggingLevel.WARN, 
                'VegvesenVolumeQueueable: Invalid response for point ' + point.Name);
            return null;
        }
        
        // Parse response
        Map<String, Object> volumeData = parseVolumeResponse(response.getBody());
        
        if (volumeData == null) {
            System.debug(LoggingLevel.WARN, 
                'VegvesenVolumeQueueable: No volume data for point ' + point.Name);
            return null;
        }
        
        // Update point with latest volume data
        point.Hourly_Volume__c = (Decimal) volumeData.get('volume');
        point.Volume_Coverage__c = (Decimal) volumeData.get('coverage');
        point.Last_Volume_Sync__c = DateTime.now();
        
        return point;
    }
    
    /**
     * @description Makes HTTP POST request to Vegvesen GraphQL API
     * @param query GraphQL query string
     * @return HttpResponse from the API
     */
    private HttpResponse makeGraphQLCallout(String query) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        
        Map<String, Object> requestBody = new Map<String, Object>{
            'query' => query,
            'variables' => null
        };
        
        req.setEndpoint(ENDPOINT_URL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(JSON.serialize(requestBody));
        req.setTimeout(120000);
        
        return http.send(req);
    }
    
    /**
     * @description Parses volume response and extracts latest hour data
     * @param responseBody JSON response string
     * @return Map with 'volume' and 'coverage' keys, or null
     */
    private Map<String, Object> parseVolumeResponse(String responseBody) {
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            
            if (root == null || root.containsKey('errors')) {
                return null;
            }
            
            // Navigate: data > trafficData > volume > byHour > edges
            Map<String, Object> data = (Map<String, Object>) root.get('data');
            if (data == null) return null;
            
            Map<String, Object> trafficData = (Map<String, Object>) data.get('trafficData');
            if (trafficData == null) return null;
            
            Map<String, Object> volume = (Map<String, Object>) trafficData.get('volume');
            if (volume == null) return null;
            
            Map<String, Object> byHour = (Map<String, Object>) volume.get('byHour');
            if (byHour == null) return null;
            
            List<Object> edges = (List<Object>) byHour.get('edges');
            if (edges == null || edges.isEmpty()) return null;
            
            // Get the last (most recent) hour data
            Map<String, Object> lastEdge = (Map<String, Object>) edges[edges.size() - 1];
            Map<String, Object> node = (Map<String, Object>) lastEdge.get('node');
            if (node == null) return null;
            
            Map<String, Object> total = (Map<String, Object>) node.get('total');
            if (total == null) return null;
            
            // Extract volume
            Map<String, Object> volumeNumbers = (Map<String, Object>) total.get('volumeNumbers');
            Decimal volumeValue = volumeNumbers != null ? 
                Decimal.valueOf(String.valueOf(volumeNumbers.get('volume'))) : null;
            
            // Extract coverage
            Map<String, Object> coverage = (Map<String, Object>) total.get('coverage');
            Decimal coverageValue = coverage != null ? 
                Decimal.valueOf(String.valueOf(coverage.get('percentage'))) : null;
            
            return new Map<String, Object>{
                'volume' => volumeValue,
                'coverage' => coverageValue
            };
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 
                'VegvesenVolumeQueueable: Parse error: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Updates traffic point records with volume data
     * @param points List of Traffic_Data__c records to update
     */
    private void updateTrafficPoints(List<Traffic_Data__c> points) {
        if (points == null || points.isEmpty()) return;
        
        System.debug('VegvesenVolumeQueueable: Updating ' + points.size() + ' points');
        
        try {
            Database.SaveResult[] results = Database.update(points, false);
            
            Integer successCount = 0;
            Integer failCount = 0;
            
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    successCount++;
                } else {
                    failCount++;
                    System.debug(LoggingLevel.ERROR, 
                        'VegvesenVolumeQueueable: Failed to update ' + points[i].Name + 
                        ': ' + results[i].getErrors()[0].getMessage());
                }
            }
            
            System.debug('VegvesenVolumeQueueable: Update complete. Success: ' + 
                successCount + ', Failed: ' + failCount);
            
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 
                'VegvesenVolumeQueueable: Update error: ' + e.getMessage());
        }
    }
}