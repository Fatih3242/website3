/**
 * VegvesenVolumeBatch
 * Batchable implementation to fetch hourly volume for Traffic_Data__c records.
 * - Processes records in chunks to avoid CPU/time limits.
 * - Allows callouts per execute chunk.
 * Usage:
 *   Database.executeBatch(new VegvesenVolumeBatch(), 100);
 */
public without sharing class VegvesenVolumeBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
    private static final String ENDPOINT_URL = 'https://trafikkdata-api.atlas.vegvesen.no';
    private Integer hoursToFetch = 24;
    
    public VegvesenVolumeBatch() { }
    public VegvesenVolumeBatch(Integer hoursToFetch) {
        this.hoursToFetch = hoursToFetch;
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query all active traffic points
        String q = 'SELECT Id, Name, Location_Name__c, Hourly_Volume__c, Last_Volume_Sync__c, Volume_Coverage__c FROM Traffic_Data__c WHERE Status__c = \'ACTIVE\'';
        return Database.getQueryLocator(q);
    }
    
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Traffic_Data__c> toUpdate = new List<Traffic_Data__c>();
        Integer updatedCount = 0;
        Integer missingCount = 0;
        Integer errorCount = 0;
        
        // Build time window once per batch
        DateTime toTime = DateTime.now();
        DateTime fromTime = toTime.addHours(-hoursToFetch);
        String fromISO = fromTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'+00:00\'');
        String toISO = toTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'+00:00\'');
        
        for (SObject sobj : scope) {
            Traffic_Data__c point = (Traffic_Data__c) sobj;
            try {
                String query = 
                    'query { ' +
                    '  trafficData(trafficRegistrationPointId: "' + point.Name + '") { ' +
                    '    volume { ' +
                    '      byHour(from: "' + fromISO + '", to: "' + toISO + '") { ' +
                    '        edges { ' +
                    '          node { ' +
                    '            from ' +
                    '            to ' +
                    '            total { ' +
                    '              volumeNumbers { volume } ' +
                    '              coverage { percentage } ' +
                    '            } ' +
                    '          } ' +
                    '        } ' +
                    '      } ' +
                    '    } ' +
                    '  } ' +
                    '}';
                
                HttpResponse resp = makeGraphQLCallout(query);
                if (resp == null || resp.getStatusCode() != 200) {
                    missingCount++;
                    continue;
                }
                Map<String, Object> parsed = parseVolumeResponse(resp.getBody());
                if (parsed == null) {
                    missingCount++;
                    continue;
                }
                Decimal volumeVal = (Decimal) parsed.get('volume');
                Decimal coverageVal = (Decimal) parsed.get('coverage');
                
                if (volumeVal != null) {
                    point.Hourly_Volume__c = volumeVal;
                } else {
                    // leave Hourly_Volume__c null if not available
                    point.Hourly_Volume__c = null;
                }
                point.Volume_Coverage__c = coverageVal;
                point.Last_Volume_Sync__c = DateTime.now();
                
                toUpdate.add(point);
                updatedCount++;
            } catch (Exception e) {
                errorCount++;
                // Minimal logging to avoid CPU overhead
                System.debug('VegvesenVolumeBatch: Error for point ' + point.Name + ' : ' + e.getMessage());
            }
        }
        
        if (!toUpdate.isEmpty()) {
            try {
                Database.update(toUpdate, false);
            } catch (DmlException de) {
                System.debug('VegvesenVolumeBatch: DML error updating batch: ' + de.getMessage());
            }
        }
        
        // Lightweight summary log per batch
        System.debug('VegvesenVolumeBatch: Batch processed. Updated=' + updatedCount + ' Missing=' + missingCount + ' Errors=' + errorCount);
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('VegvesenVolumeBatch: Finish called');
    }
    
    // HTTP callout helper
    private HttpResponse makeGraphQLCallout(String query) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        Map<String, Object> body = new Map<String, Object>{ 'query' => query, 'variables' => null };
        req.setEndpoint(ENDPOINT_URL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(JSON.serialize(body));
        req.setTimeout(120000);
        return http.send(req);
    }
    
    // Robust parser: scan edges from newest->oldest to find first numeric volume
    private Map<String, Object> parseVolumeResponse(String responseBody) {
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            if (root == null || root.containsKey('errors')) return null;
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
            // iterate from last to first
            for (Integer i = edges.size() - 1; i >= 0; i--) {
                Map<String, Object> edge = (Map<String, Object>) edges[i];
                if (edge == null) continue;
                Map<String, Object> node = (Map<String, Object>) edge.get('node');
                if (node == null) continue;
                Map<String, Object> total = (Map<String, Object>) node.get('total');
                if (total == null) continue;
                Map<String, Object> volumeNumbers = (Map<String, Object>) total.get('volumeNumbers');
                Decimal volumeValue = null;
                if (volumeNumbers != null && volumeNumbers.get('volume') != null) {
                    try {
                        volumeValue = Decimal.valueOf(String.valueOf(volumeNumbers.get('volume')));
                    } catch (Exception ex) {
                        volumeValue = null;
                    }
                }
                Map<String, Object> coverage = (Map<String, Object>) total.get('coverage');
                Decimal coverageValue = null;
                if (coverage != null && coverage.get('percentage') != null) {
                    try {
                        coverageValue = Decimal.valueOf(String.valueOf(coverage.get('percentage')));
                    } catch (Exception ex) {
                        coverageValue = null;
                    }
                }
                if (volumeValue != null) {
                    return new Map<String, Object>{ 'volume' => volumeValue, 'coverage' => coverageValue };
                } else if (coverageValue != null) {
                    // No numeric volume, but we have coverage info; return null volume and coverage
                    return new Map<String, Object>{ 'volume' => null, 'coverage' => coverageValue };
                }
            }
            return null;
        } catch (Exception e) {
            System.debug('VegvesenVolumeBatch: parse error: ' + e.getMessage());
            return null;
        }
    }
}