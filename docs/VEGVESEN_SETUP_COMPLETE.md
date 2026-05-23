# Vegvesen Traffic API Integration - Complete Setup Guide

## 📋 Overview

Bu entegrasyon 2 aşamadan oluşur:
1. **Phase 1**: Static traffic registration points (Oslo) - Haftada 1 kez
2. **Phase 2**: Hourly volume data - Her saat

---

## 🔧 Prerequisites

### 1. Remote Site Settings
Setup → Remote Site Settings → New Remote Site

```
Remote Site Name: Vegvesen_Traffic_API
Remote Site URL: https://trafikkdata-api.atlas.vegvesen.no
Description: Norwegian Traffic Data GraphQL API
Active: ✓
```

### 2. Traffic_Data__c Custom Fields

Mevcut field'lar:
- ✅ `Name` (Text, External ID)
- ✅ `Location_Name__c` (Text)
- ✅ `Image_Url__c` (Long Text Area)
- ✅ `Location__c` (Geolocation)
- ✅ `Status__c` (Text/Picklist)

**Yeni eklenecek field'lar** (Phase 2 için):

| API Name | Label | Type | Description |
|----------|-------|------|-------------|
| `Hourly_Volume__c` | Hourly Volume | Number(10,0) | Latest hour traffic volume |
| `Last_Volume_Sync__c` | Last Volume Sync | DateTime | Last volume sync timestamp |
| `Volume_Coverage__c` | Volume Coverage | Number(5,2) | Data quality percentage |

### 3. Deployed Classes

- ✅ `VegvesenPointSyncQueueable.cls` - Oslo traffic points sync
- ✅ `VegvesenPointSyncSchedulable.cls` - Weekly scheduler
- ✅ `VegvesenVolumeQueueable.cls` - Hourly volume sync

---

## 🚀 Phase 1: Static Point Sync (Oslo Only)

### Manual Test

```apex
// Execute Anonymous - Test Oslo point sync
System.enqueueJob(new VegvesenPointSyncQueueable());

// Check job status
SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedDate
FROM AsyncApexJob
WHERE ApexClass.Name = 'VegvesenPointSyncQueueable'
ORDER BY CreatedDate DESC
LIMIT 1;

// Verify data
SELECT COUNT() FROM Traffic_Data__c WHERE Status__c = 'ACTIVE';
SELECT Name, Location_Name__c, Location__Latitude__s, Location__Longitude__s
FROM Traffic_Data__c
LIMIT 5;
```

### Schedule Weekly Job

```apex
// Execute Anonymous - Schedule for every Sunday at 2:00 AM
System.schedule(
    'Vegvesen Weekly Point Sync',
    '0 0 2 ? * SUN',
    new VegvesenPointSyncSchedulable()
);

// Verify scheduled job
SELECT Id, CronJobDetail.Name, State, NextFireTime
FROM CronTrigger
WHERE CronJobDetail.Name LIKE '%Vegvesen%';
```

### Expected Results

- **~500-1000 traffic points** from Oslo (countyId: 3)
- Each record has:
  - Unique ID (Name field)
  - Location name
  - GPS coordinates
  - Full JSON data in Image_Url__c
  - Status: ACTIVE

---

## 📊 Phase 2: Volume Data Sync

### Prerequisites

1. **Custom field'ları ekleyin** (yukarıda listelendi)
2. Phase 1 başarıyla tamamlanmış olmalı

### Manual Test

```apex
// Execute Anonymous - Test volume sync
System.enqueueJob(new VegvesenVolumeQueueable());

// Check processing
SELECT Id, Status, NumberOfErrors, CreatedDate
FROM AsyncApexJob
WHERE ApexClass.Name = 'VegvesenVolumeQueueable'
ORDER BY CreatedDate DESC
LIMIT 5;

// Verify volume data
SELECT Name, Location_Name__c, Hourly_Volume__c, 
       Volume_Coverage__c, Last_Volume_Sync__c
FROM Traffic_Data__c
WHERE Hourly_Volume__c != null
LIMIT 10;
```

### How It Works

1. **Batch Processing**: 50 points per run
2. **Auto-chaining**: Automatically processes next batch
3. **Hourly data**: Fetches last 24 hours, stores latest
4. **Smart ordering**: Processes oldest synced points first

### Schedule Hourly Sync

```apex
// Execute Anonymous - Schedule hourly at :05 past every hour
System.schedule(
    'Vegvesen Hourly Volume Sync',
    '0 5 * * * ?',
    new VegvesenVolumeSyncSchedulable()
);
```

**NOTE**: `VegvesenVolumeSyncSchedulable` class'ını oluşturmanız gerekecek:

```apex
public class VegvesenVolumeSyncSchedulable implements Schedulable {
    public void execute(SchedulableContext sc) {
        System.enqueueJob(new VegvesenVolumeQueueable());
    }
}
```

---

## ⚙️ Configuration

### Change Oslo to All Norway

`VegvesenPointSyncQueueable.cls` içinde:

```java
// Current (Oslo only)
'trafficRegistrationPoints(searchQuery: { countyIds: [3] }) {'

// Change to (All Norway)
'trafficRegistrationPoints {'
```

### Adjust Sync Frequency

**Point Sync** (currently weekly):
```apex
'0 0 2 ? * SUN'  // Every Sunday 2:00 AM
'0 0 2 1 * ?'    // First day of month 2:00 AM
```

**Volume Sync** (recommended hourly):
```apex
'0 5 * * * ?'    // Every hour at :05
'0 0 */3 * * ?'  // Every 3 hours
```

### Batch Size (Volume Sync)

`VegvesenVolumeQueueable.cls` içinde:

```java
private static final Integer MAX_POINTS_PER_RUN = 50;  // Current
// Increase to 100 for faster processing (more API calls)
```

---

## 🐛 Troubleshooting

### Job'u Durdurmak

```apex
// Find running jobs
SELECT Id, ApexClass.Name, Status, CreatedDate
FROM AsyncApexJob
WHERE ApexClass.Name IN ('VegvesenPointSyncQueueable', 'VegvesenVolumeQueueable')
AND Status IN ('Queued', 'Processing')
ORDER BY CreatedDate DESC;

// Abort a job
System.abortJob('JOB_ID_HERE');
```

### Scheduled Job'u Silmek

```apex
// Find scheduled jobs
SELECT Id, CronJobDetail.Name FROM CronTrigger
WHERE CronJobDetail.Name LIKE '%Vegvesen%';

// Delete scheduled job
System.abortJob('CRON_JOB_ID_HERE');
```

### Debug Logs

```apex
// Check recent logs
SELECT Id, Operation, Status, DurationMilliseconds, StartTime
FROM ApexLog
WHERE Operation LIKE '%Vegvesen%'
ORDER BY StartTime DESC
LIMIT 10;
```

### Common Issues

| Issue | Solution |
|-------|----------|
| 401 Unauthorized | Check Remote Site Settings |
| Heap size exceeded | Reduce batch size in volume sync |
| No data returned | Verify countyId filter (Oslo = 3) |
| GraphQL errors | Check API documentation for schema changes |

---

## 📈 Monitoring

### Key Metrics

```apex
// Total points synced
SELECT COUNT() FROM Traffic_Data__c WHERE Status__c = 'ACTIVE';

// Points with volume data
SELECT COUNT() FROM Traffic_Data__c WHERE Hourly_Volume__c != null;

// Average coverage quality
SELECT AVG(Volume_Coverage__c) FROM Traffic_Data__c 
WHERE Volume_Coverage__c != null;

// Last sync times
SELECT MIN(Last_Volume_Sync__c), MAX(Last_Volume_Sync__c)
FROM Traffic_Data__c;
```

### Volume Trends

```apex
// High traffic points (top 10)
SELECT Name, Location_Name__c, Hourly_Volume__c
FROM Traffic_Data__c
WHERE Hourly_Volume__c != null
ORDER BY Hourly_Volume__c DESC
LIMIT 10;

// Low quality data (coverage < 80%)
SELECT Name, Location_Name__c, Volume_Coverage__c
FROM Traffic_Data__c
WHERE Volume_Coverage__c < 80
ORDER BY Volume_Coverage__c ASC;
```

---

## 🎯 Best Practices

1. **Start Small**: Test with Oslo only first
2. **Monitor Heap**: Watch governor limits during volume sync
3. **Scheduled Jobs**: Don't run point sync too frequently (weekly is enough)
4. **Volume Sync**: Hourly is recommended for real-time data
5. **Error Handling**: Check debug logs regularly
6. **Data Quality**: Monitor `Volume_Coverage__c` field

---

## 📚 API Documentation

- **Official Docs**: https://trafikkdata.atlas.vegvesen.no/om-api
- **GraphiQL Explorer**: https://trafikkdata.no/graphql
- **API Endpoint**: https://trafikkdata-api.atlas.vegvesen.no

---

## 🔄 Upgrade Path

### Current Setup (Oslo, Weekly)
- ~500-1000 points
- Low system load
- Perfect for testing

### Full Norway (All Counties)
- ~10,000 points
- Higher heap usage
- Requires careful monitoring
- Change filter in `VegvesenPointSyncQueueable`

### Historical Data
- API supports historical volume data
- Modify `HOURS_TO_FETCH` in `VegvesenVolumeQueueable`
- Be careful with heap limits

---

## ✅ Checklist

### Initial Setup
- [ ] Remote Site Settings configured
- [ ] Custom fields created (Phase 2)
- [ ] Classes deployed
- [ ] Manual point sync tested
- [ ] Data verified in Traffic_Data__c

### Phase 1 Production
- [ ] Scheduled job created (weekly)
- [ ] First sync completed successfully
- [ ] Monitoring queries saved
- [ ] Error handling tested

### Phase 2 Production
- [ ] Volume sync tested manually
- [ ] Hourly schedule configured
- [ ] Volume data appears in records
- [ ] Coverage quality monitored

---

## 🆘 Support

**Debug Commands in Clipboard**: Paste bu komutu Developer Console'da:
```apex
System.abortJob([SELECT Id FROM AsyncApexJob 
WHERE ApexClass.Name = 'VegvesenPointSyncQueueable' 
AND Status IN ('Queued', 'Processing') 
ORDER BY CreatedDate DESC LIMIT 1].Id);
```

**Contact**: API issues için trafikkdata@vegvesen.no