/*
Apex execute anonymous script to perform a GraphQL introspection query against the Vegvesen endpoint.

Usage:
- If you use a Named Credential in your org, set ENDPOINT to 'callout:YourNamedCredential'
  (e.g. callout:VegvesenTrafficAPI). Ensure the Named Credential's URL matches the API host.
- Run this in Anonymous Apex (Developer Console > Execute Anonymous) or via `sfdx force:apex:execute -f scripts/apex/vegvesen_introspection.apex`.
- Paste the logged output (System.debug) here for me to analyze.

What it does:
- Sends the standard GraphQL introspection query to the endpoint.
- Logs a trimmed portion of the returned schema JSON.
- You can change the ENDPOINT constant to your direct URL (https://trafikkdata-api.atlas.vegvesen.no) if you don't use a Named Credential,
  but for production orgs a Named Credential or Remote Site is recommended.

Notes:
- The response can be large; the script logs only the "types" section names and the specific input type for 'TrafficRegistrationPointSearchInput'
  if present. If the input type name differs, the script also logs possible input types that include 'TrafficRegistration' in the name.
*/

String ENDPOINT = 'callout:VegvesenTrafficAPI'; // Change if you need direct endpoint, e.g. 'https://trafikkdata-api.atlas.vegvesen.no/graphql'
String INTROSPECTION_QUERY = 
    'query IntrospectionQuery { __schema { types { name kind inputFields { name type { name kind ofType { name kind } } } } } }';

// Build request body
Map<String, Object> requestBody = new Map<String, Object>{
    'query' => INTROSPECTION_QUERY,
    'variables' => null
};

HttpRequest req = new HttpRequest();
req.setEndpoint(ENDPOINT);
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setHeader('Accept', 'application/json');
req.setBody(JSON.serialize(requestBody));
req.setTimeout(120000);

Http http = new Http();
try {
    HttpResponse res = http.send(req);
    if (res == null) {
        System.debug('INTROSPECTION: No response received');
        return;
    }
    if (res.getStatusCode() != 200) {
        System.debug('INTROSPECTION: Non-200 status: ' + res.getStatusCode());
        System.debug('INTROSPECTION: Body: ' + res.getBody());
        return;
    }
    // Parse response
    Map<String, Object> jsonResp = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    if (jsonResp.containsKey('errors')) {
        System.debug('INTROSPECTION: GraphQL returned errors: ' + JSON.serialize(jsonResp.get('errors')));
        return;
    }
    Map<String, Object> schema = (Map<String, Object>) jsonResp.get('data');
    if (schema == null) {
        System.debug('INTROSPECTION: No data field in response');
        return;
    }
    Map<String, Object> schemaRoot = (Map<String, Object>) schema.get('__schema');
    List<Object> types = (List<Object>) schemaRoot.get('types');
    // Log types that look relevant and attempt to find a searchQuery input type
    System.debug('INTROSPECTION: Found ' + (types != null ? types.size() : 0) + ' types in schema');
    
    // Look for any input object type whose name contains "TrafficRegistration" or "Search"
    List<String> candidateNames = new List<String>();
    for (Object t : types) {
        Map<String, Object> typeMap = (Map<String, Object>) t;
        String typeName = (String) typeMap.get('name');
        String kind = (String) typeMap.get('kind');
        if (typeName == null) continue;
        if (typeName.toLowerCase().contains('trafficregistration') || typeName.toLowerCase().contains('search')) {
            candidateNames.add(typeName + ' (' + kind + ')');
            // Log its inputFields if present
            if (typeMap.containsKey('inputFields') && typeMap.get('inputFields') != null) {
                List<Object> inputFields = (List<Object>) typeMap.get('inputFields');
                System.debug('INTROSPECTION: Input type: ' + typeName + ' has ' + inputFields.size() + ' fields');
                for (Object f : inputFields) {
                    Map<String, Object> field = (Map<String, Object>) f;
                    String fname = (String) field.get('name');
                    Map<String, Object> ftype = (Map<String, Object>) field.get('type');
                    String ftypeName = (ftype != null && ftype.get('name') != null) ? (String) ftype.get('name') : JSON.serialize(ftype);
                    System.debug(' - field: ' + fname + ' type: ' + ftypeName);
                }
            }
        }
    }
    System.debug('INTROSPECTION: Candidate input types: ' + JSON.serialize(candidateNames));
    
} catch (Exception e) {
    System.debug('INTROSPECTION: Exception during HTTP call: ' + e.getMessage());
}