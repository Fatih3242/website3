# Vegvesen Traffic Data Integration - Setup Guide

## Overview

This integration syncs traffic registration point data from the Norwegian Public Roads Administration (Vegvesen) GraphQL API into Salesforce's `Traffic_Data__c` custom object.

**Current Implementation:** Static traffic registration points sync (Phase 1)
**Future Implementation:** Hourly volume data sync (Phase 2)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    VEGVESEN INTEGRATION                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Phase 1: Static Points (VegvesenPointSyncQueueable)           │
│  ┌───────────────┐      ┌──────────────┐      ┌─────────────┐ │
│  │  GraphQL API  │─────▶│  Queueable   │─────▶│ Traffic_    │ │
│  │  /graphql     │      │  Callout     │      │ Data__c     │ │
│  └───────────────┘      └──────────────┘      └─────────────┘ │
│       • id                  • Parse JSON           • Name      │
│       • name                • Transform             • Location  │
│       • location            • Validate              • Status    │
│                             • Upsert                           │
│                                                                 │
│  Phase 2: Volume Data (Future - VegvesenVolumeDataQueueable)  │
│  ┌───────────────┐      ┌──────────────┐      ┌─────────────┐ │
│  │  GraphQL API  │─────▶│  Queueable   │─────▶│ Traffic_    │ │
│  │  trafficData  │      │  Hourly Sync │      │ Data__c     │ │
│  └───────────────┘      └──────────────┘      └─────────────┘ │
│       • volume              • Last 1hr            • Vehicle_   │
│       • timestamp           • By point ID          Count__c   │
│                                                                 │
│  Scheduling:                                                    │
│  • Static Points: Weekly (Sunday 2 AM)                         │
│  • Volume Data: Hourly                                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### 1. Salesforce Custom Object: Traffic_Data__c

Create the custom object with the following fields:

| Field API Name | Type | Length | Properties | Description |
|---|---|---|---|---|
| `Name` | Text/Auto-Number | 80 | **External ID**, Unique | Traffic registration point ID |
| `Location_Name__c` | Text | 255 | - | Descriptive name of the location |
| `Image_Url__c` | Long Text Area | 131,072 | - | Full JSON payload for debugging |
| `Location__c` | Geolocation | - | - | GPS coordinates (creates Latitude/Longitude) |
| `Location__Latitude__s` | Number | - | Auto-created | Latitude component |
| `Location__Longitude__s` | Number | - | Auto-created | Longitude component |
| `Status__c` | Text/Picklist | 50 | - | Status flag (e.g., 'ACTIVE') |
| `Congestion_Level__c` | Text | - | Optional (Phase 2) | Hourly vehicle count |

**Quick Setup via Metadata API:**

```xml
<!-- force-app/main/default/objects/Traffic_Data__c/Traffic_Data__c.object-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Traffic Data</label>
    <pluralLabel>Traffic Data</pluralLabel>
    <nameField>
        <label>Point ID</label>
        <type>Text</type>
    </nameField>
    <deploymentStatus>Deployed</deploymentStatus>
    <sharingModel>ReadWrite</sharingModel>
</CustomObject>
```

### 2. Remote Site Settings

**CRITICAL:** Must be configured before running the integration.

#### Setup Steps:

1. Navigate to **Setup** → **Security** → **Remote Site Settings**
2. Click **New Remote Site**
3. Configure:
   - **Remote Site Name:** `Vegvesen_Trafikkdata`
   - **Remote Site URL:** `https://www.vegvesen.no`
   - **Active:** ✅ Checked
   - **Description:** `Norwegian Public Roads Administration Traffic Data API`
4. Click **Save**

#### Alternative: Deploy via Metadata

```xml
<!-- force-app/main/default/remoteSiteSettings/Vegvesen_Trafikkdata.remoteSite-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<RemoteSiteSetting xmlns="http://soap.sforce.com/2006/04/metadata">
    <disableProtocolSecurity>false</disableProtocolSecurity>
    <isActive>true</isActive>
    <url>https://www.vegvesen.no</url>
</RemoteSiteSetting>
```

---

## Deployment

### Step 1: Deploy Apex Classes

```bash
# Using Salesforce CLI
sf project deploy start --source-dir force-app/main/default/classes/VegvesenPointSyncQueueable.cls

# Or deploy all metadata
sf project deploy start
```

### Step 2: Verify Deployment

```bash
# Check deployment status
sf project deploy report

# Run Apex tests (when test class is created)
sf apex run test --class-names VegvesenPointSyncQueueableTest --result-format human
```

### Step 3: Configure Remote Site Settings

See [Prerequisites Section 2](#2-remote-site-settings) above.

---

## Usage

### Option 1: Manual Execution (Testing)

#### Via Developer Console:

1. Open **Developer Console**
2. Navigate to **Debug** → **Open Execute Anonymous Window**
3. Paste and execute:

```java
System.debug('Starting Vegvesen Point Sync');
Id jobId = System.enqueueJob(new VegvesenPointSyncQueueable());
System.debug('Job ID: ' + jobId);
```

#### Via VS Code:

1. Open `scripts/apex/VegvesenPointSync_ExecuteAnonymous.apex`
2. Select the code in Option 1 (lines 42-47)
3. Right-click → **SFDX: Execute Anonymous Apex with Currently Selected Text**

### Option 2: Scheduled Execution (Production)

Create a scheduler class (to be implemented in Phase 2):

```java
public class VegvesenPointSyncScheduler implements Schedulable {
    public void execute(SchedulableContext ctx) {
        System.enqueueJob(new VegvesenPointSyncQueueable());
    }
}
```

Schedule for weekly execution:

```java
// Execute every Sunday at 2:00 AM
String cronExp = '0 0 2 ? * SUN';
System.schedule('Vegvesen Point Sync - Weekly', cronExp, new VegvesenPointSyncScheduler());
```

---

## Monitoring

### Check Job Status

```java
List<AsyncApexJob> jobs = [
    SELECT Id, Status, NumberOfErrors, CreatedDate, CompletedDate, ExtendedStatus
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'VegvesenPointSyncQueueable'
    ORDER BY CreatedDate DESC 
    LIMIT 5
];

for (AsyncApexJob job : jobs) {
    System.debug('Job: ' + job.Id + ' | Status: ' + job.Status + ' | Errors: ' + job.NumberOfErrors);
}
```

### Via UI:

**Setup** → **Environments** → **Jobs** → **Apex Jobs**

Look for jobs with Apex Class: `VegvesenPointSyncQueueable`

### Verify Data Import

```java
Integer count = [SELECT COUNT() FROM Traffic_Data__c WHERE Status__c = 'ACTIVE'];
System.debug('Total active traffic points: ' + count);

// View sample records
List<Traffic_Data__c> samples = [
    SELECT Name, Location_Name__c, Location__Latitude__s, Location__Longitude__s
    FROM Traffic_Data__c 
    WHERE Status__c = 'ACTIVE'
    LIMIT 5
];

for (Traffic_Data__c td : samples) {
    System.debug(td.Name + ' - ' + td.Location_Name__c + ' @ ' + 
                 td.Location__Latitude__s + ', ' + td.Location__Longitude__s);
}
```

---

## Troubleshooting

### Common Issues

| Error | Cause | Solution |
|---|---|---|
| **Unauthorized endpoint** | Remote Site not configured | Add `https://www.vegvesen.no` to Remote Site Settings |
| **Field does not exist: Location__Latitude__s** | Geolocation field missing | Create `Location__c` Geolocation field on `Traffic_Data__c` |
| **duplicate value found: Name** | Duplicate point IDs | Ensure `Name` field is unique or External ID |
| **HTTP 405 Method Not Allowed** | Wrong HTTP method | Already handled (uses POST) |
| **HTTP 403 Forbidden** | API access restricted | Check API availability, may need VPN if testing from outside Norway |
| **Timeout** | Large data volume | Increase timeout (currently 120s) or filter by region |
| **No records imported** | JSON parsing issue | Check debug logs for GraphQL errors |

### Debug Logs Analysis

Enable debug logs:
1. **Setup** → **Debug Logs**
2. Click **New**
3. Select your user
4. Set **Apex Code** = DEBUG
5. Duration: 1 hour

Look for these log markers:
- `VegvesenPointSyncQueueable: Starting execution`
- `VegvesenPointSyncQueueable: Response status: 200`
- `VegvesenPointSyncQueueable: Found X traffic points`
- `VegvesenPointSyncQueueable: Upsert completed`

### Manual API Test

Test the API directly using cURL:

```bash
curl -X POST https://www.vegvesen.no/trafikkdata/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"query { trafficRegistrationPoints { id name location { coordinates { latLon { lat lon } } } } }"}'
```

Expected response:
```json
{
  "data": {
    "trafficRegistrationPoints": [
      {
        "id": "12345678",
        "name": "Oslo - Example Location",
        "location": {
          "coordinates": {
            "latLon": {
              "lat": 59.9139,
              "lon": 10.7522
            }
          }
        }
      }
    ]
  }
}
```

---

## API Details

### Endpoint
- **URL:** `https://www.vegvesen.no/trafikkdata/graphql`
- **Method:** POST
- **Content-Type:** application/json

### GraphQL Query (Phase 1)

```graphql
query {
  trafficRegistrationPoints {
    id
    name
    location {
      coordinates {
        latLon {
          lat
          lon
        }
      }
    }
  }
}
```

### Response Structure

```json
{
  "data": {
    "trafficRegistrationPoints": [
      {
        "id": "string",
        "name": "string",
        "location": {
          "coordinates": {
            "latLon": {
              "lat": number,
              "lon": number
            }
          }
        }
      }
    ]
  }
}
```

---

## Governor Limits

### Current Implementation Safety

| Resource | Limit | Usage | Safe? |
|---|---|---|---|
| **Queueable Jobs** | 50/transaction | 1 | ✅ |
| **Callouts** | 100/transaction | 1 | ✅ |
| **Callout Time** | 120s/callout | 120s | ✅ |
| **Heap Size** | 6 MB (sync) | ~2-3 MB | ✅ |
| **DML Rows** | 10,000/transaction | <5,000 expected | ✅ |
| **SOQL Queries** | 100/transaction | 0 | ✅ |

### Bulk Safety Features

- Uses `Database.upsert()` with `allOrNone=false` for partial success
- No SOQL queries in loops
- Efficient JSON parsing with null-safety
- Comprehensive error handling
- Detailed debug logging

---

## Data Mapping

| Source (API) | Target (Salesforce) | Transformation |
|---|---|---|
| `id` | `Name` | Direct mapping (External ID) |
| `name` | `Location_Name__c` | Direct mapping, default to 'Unknown' if null |
| *Full JSON* | `Image_Url__c` | JSON.serialize(entire point object) |
| `location.coordinates.latLon.lat` | `Location__Latitude__s` | Decimal conversion with validation |
| `location.coordinates.latLon.lon` | `Location__Longitude__s` | Decimal conversion with validation |
| *Static value* | `Status__c` | Always 'ACTIVE' |

---

## Next Steps (Phase 2)

1. **Create Volume Data Queueable:**
   - Class: `VegvesenVolumeDataQueueable`
   - Query hourly traffic volume using `trafficData` GraphQL query
   - Update `Vehicle_Count__c` field
   - Use existing `Name` field to match records

2. **Create Scheduler Classes:**
   - `VegvesenPointSyncScheduler` (weekly)
   - `VegvesenVolumeDataScheduler` (hourly)

3. **Add Monitoring:**
   - Custom notification on sync failures
   - Dashboard for data quality metrics
   - Alert if no data received in 24 hours

4. **Build Visualization:**
   - Lightning Web Component with map integration
   - Real-time traffic volume display
   - Historical trend charts

---

## Files Reference

```
force-app/main/default/
├── classes/
│   ├── VegvesenPointSyncQueueable.cls
│   └── VegvesenPointSyncQueueable.cls-meta.xml
├── objects/
│   └── Traffic_Data__c/
│       ├── Traffic_Data__c.object-meta.xml
│       └── fields/
│           ├── Location_Name__c.field-meta.xml
│           ├── Image_Url__c.field-meta.xml
│           ├── Location__c.field-meta.xml
│           └── Status__c.field-meta.xml
└── remoteSiteSettings/
    └── Vegvesen_Trafikkdata.remoteSite-meta.xml

scripts/apex/
└── VegvesenPointSync_ExecuteAnonymous.apex

docs/
└── VEGVESEN_INTEGRATION_SETUP.md (this file)
```

---

## Support & Resources

- **Vegvesen API Docs:** https://www.vegvesen.no/trafikkdata/api
- **Salesforce Queueable:** https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_queueing_jobs.htm
- **GraphQL:** https://graphql.org/learn/

---

## Version History

| Version | Date | Changes |
|---|---|---|
| 1.0 | 2026-05-22 | Initial release - Static points sync |
| 1.1 | TBD | Add hourly volume data sync |
| 1.2 | TBD | Add scheduler and monitoring |

---

## License

Internal Salesforce Integration - Fatih SARI © 2026