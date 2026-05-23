/**
 * Schedulable wrapper to run VegvesenVolumeBatch on a schedule.
 * Usage (via System.schedule or Setup → Apex Classes → Schedule Apex):
 *   System.schedule('Vegvesen Volume Hourly', '0 0 * * * ? *', new VegvesenVolumeBatchSchedulable());
 */
global class VegvesenVolumeBatchSchedulable implements Schedulable {
    global void execute(SchedulableContext sc) {
        // Execute the batch with a chunk size of 100
        try {
            Database.executeBatch(new VegvesenVolumeBatch(), 100);
        } catch (Exception e) {
            System.debug('VegvesenVolumeBatchSchedulable: Failed to execute batch: ' + e.getMessage());
        }
    }
}