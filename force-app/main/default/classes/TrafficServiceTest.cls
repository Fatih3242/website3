/**
 * @description       : 
 * @author            : Fatih SARI
 * @group             : 
 * @last modified on  : 05-16-2026
 * @last modified by  : Fatih SARI
**/
@isTest
private class TrafficServiceTest {

    class MockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            res.setBody('{"data":[{"location":"Oslo","lat":59.91,"lon":10.75,"congestion":3,"status":"Active"}]}');

            return res;
        }
    }

    @isTest
    static void testFetchTrafficData() {

        Test.setMock(HttpCalloutMock.class, new MockResponse());

        Test.startTest();
        List<Traffic_Data__c> result = TrafficService.fetchTrafficData();
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('Oslo', result[0].Location_Name__c);
    }
}