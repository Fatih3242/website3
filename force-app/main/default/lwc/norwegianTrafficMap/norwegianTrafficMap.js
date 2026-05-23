import { LightningElement, track } from 'lwc';
import getTrafficData from '@salesforce/apex/NorwegianTrafficMapController.getTrafficData';

export default class NorwegianTrafficMap extends LightningElement {

@track mapMarkers = [];

@track markerCount = 0;

isLoading = true;

zoomLevel = 10;

mapCenter = {

    location: {

        Latitude: 59.9139,

        Longitude: 10.7522
    }
};

connectedCallback() {

    this.loadData();
}

loadData() {

    this.isLoading = true;

    getTrafficData()

        .then(result => {

            console.log('TRAFFIC RESULT', JSON.stringify(result));

            if (result && result.length > 0) {

                this.mapMarkers = result

                    .filter(item =>
                        item.Location__Latitude__s &&
                        item.Location__Longitude__s
                    )

                    .map(item => this.buildMarker(item));

                this.markerCount = this.mapMarkers.length;

            } else {

                this.mapMarkers = [];

                this.markerCount = 0;
            }

            console.log('MAP MARKERS', JSON.stringify(this.mapMarkers));

            this.isLoading = false;
        })

        .catch(error => {

            console.error('MAP ERROR', JSON.stringify(error));

            this.isLoading = false;
        });
}

buildMarker(item) {

    let volume = null;

    if (item.numericVolume !== undefined && item.numericVolume !== null) {

        volume = Number(item.numericVolume);

    } else if (item.Hourly_Volume__c !== undefined && item.Hourly_Volume__c !== null) {

        volume = Number(item.Hourly_Volume__c);

    } else if (item.Volume__c !== undefined && item.Volume__c !== null) {

        volume = Number(item.Volume__c);
    }

    let color = '#6b7280';

    let status = 'Traffic data updating';

    if (volume !== null && !isNaN(volume)) {

        if (volume >= 700) {

            color = '#dc2626';

            status = 'Critical traffic';

        } else if (volume >= 300) {

            color = '#f97316';

            status = 'Heavy traffic';

        } else if (volume >= 100) {

            color = '#facc15';

            status = 'Moderate traffic';

        } else {

            color = '#22c55e';

            status = 'Light traffic';
        }
    }

    let description = status;

    if (volume !== null && !isNaN(volume)) {

        description += ' • Vehicles this hour: ' + volume;
    }

    return {

        location: {

            Latitude: Number(item.Location__Latitude__s),

            Longitude: Number(item.Location__Longitude__s)
        },

        title: item.Location_Name__c || item.Name,

        description: description,

        mapIcon: {

            path: 'M12 2C8 2 5 5 5 9c0 5 7 13 7 13s7-8 7-13c0-4-3-7-7-7z',

            fillColor: color,

            fillOpacity: 1,

            strokeColor: '#111827',

            strokeWeight: 1,

            scale: 1.5
        }  
    };
}

}