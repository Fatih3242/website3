/**
 * @description       : Norwegian Traffic Integration
 * @author            : Fatih SARI
**/

public with sharing class VegvesenTrafficQueueable
implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {

        List<Traffic_Data__c> records =
            new List<Traffic_Data__c>();

        Http http = new Http();

        HttpRequest request =
            new HttpRequest();

        request.setEndpoint(
            'https://nvdbapiles.atlas.vegvesen.no/vegobjekter/573?kommune=0301&srid=4326'
        );

        request.setMethod('GET');

        request.setHeader(
            'Accept',
            'application/json'
        );

        request.setHeader(
            'User-Agent',
            'Mozilla/5.0 Salesforce CRM Integration'
        );

        HttpResponse response =
            http.send(request);

        System.debug(
            'MASTER RESPONSE: ' +
            response.getBody()
        );

        Map<String,Object> masterResult =
            (Map<String,Object>)
            JSON.deserializeUntyped(
                response.getBody()
            );

        List<Object> objects =
            (List<Object>)
            masterResult.get('objekter');

        if(objects == null){
            return;
        }

        Integer counter = 0;

        for(Object obj : objects){

            if(counter >= 20){
                break;
            }

            Map<String,Object> item =
                (Map<String,Object>) obj;

            String detailUrl =
                String.valueOf(
                    item.get('href')
                );

            if(String.isBlank(detailUrl)){
                continue;
            }

            HttpRequest detailRequest =
                new HttpRequest();

            detailRequest.setEndpoint(
                detailUrl + '?srid=4326'
            );

            detailRequest.setMethod('GET');

            detailRequest.setHeader(
                'Accept',
                'application/json'
            );

            detailRequest.setHeader(
                'User-Agent',
                'Mozilla/5.0 Salesforce CRM Integration'
            );

            HttpResponse detailResponse =
                http.send(detailRequest);

            System.debug(
                'DETAIL RESPONSE: ' +
                detailResponse.getBody()
            );

            Map<String,Object> detail =
                (Map<String,Object>)
                JSON.deserializeUntyped(
                    detailResponse.getBody()
                );

            if(detail == null){
                continue;
            }

            Traffic_Data__c traffic =
                new Traffic_Data__c();

            traffic.Status__c =
                'Active';

            /*
             * METADATA
             */

            Map<String,Object> metadata =
                (Map<String,Object>)
                detail.get('metadata');

            if(metadata != null){

                traffic.Location_Name__c =
                    String.valueOf(
                        metadata.get('startdato')
                    );

            }

            /*
             * GEOMETRY
             */

            Map<String,Object> geometry =
                (Map<String,Object>)
                detail.get('geometri');

            if(geometry == null){
                continue;
            }

            String wkt =
                String.valueOf(
                    geometry.get('wkt')
                );

            if(String.isBlank(wkt)){
                continue;
            }

            System.debug(
                'WKT VALUE: ' +
                wkt
            );

            String clean =
                wkt
                .replace('POINT Z(','')
                .replace('POINT(','')
                .replace('LINESTRING Z (','')
                .replace('LINESTRING(','')
                .replace(')','');

            List<String> lineParts =
                clean.split(',');

            if(lineParts.isEmpty()){
                continue;
            }

            String firstCoordinate =
                lineParts[0];

            List<String> coords =
                new List<String>();

            for(String c : firstCoordinate.split(' ')){

                if(String.isNotBlank(c)){
                    coords.add(c);
                }

            }

            if(coords.size() < 2){
                continue;
            }

            try{

                traffic.Location__Longitude__s =
                    Decimal.valueOf(
                        coords[0]
                    );

                traffic.Location__Latitude__s =
                    Decimal.valueOf(
                        coords[1]
                    );

            }catch(Exception e){

                System.debug(
                    'COORD ERROR: ' +
                    e.getMessage()
                );

                continue;

            }

            /*
             * DESCRIPTION
             */

            String description =
                '';

            Map<String,Object> locationMap =
                (Map<String,Object>)
                detail.get('lokasjon');

            if(locationMap != null){

                description +=
                    '<b>Location:</b><br/>' +
                    JSON.serializePretty(locationMap) +
                    '<br/><br/>';

            }

            if(metadata != null){

                description +=
                    '<b>Metadata:</b><br/>' +
                    JSON.serializePretty(metadata);

            }

            traffic.Image_URL__c =
                description;

            records.add(traffic);

            counter++;

        }

        if(!records.isEmpty()){

            delete [
                SELECT Id
                FROM Traffic_Data__c
            ];

            insert records;

        }

        System.debug(
            'INSERTED RECORDS: ' +
            records.size()
        );

    }

}
