/**
 * Schedulable wrapper to enqueue VegvesenPointSyncQueueable on a weekly schedule.
 * Usage (via System.schedule or Setup → Apex Classes → Schedule Apex):
 *   System.schedule('Vegvesen Point Sync Weekly', '0 0 2 ? * MON *', new VegvesenPointSyncSchedulable());
 */
global class VegvesenPointSyncSchedulable implements Schedulable {
    global void execute(SchedulableContext sc) {
        try {
            System.enqueueJob(new VegvesenPointSyncQueueable());
        } catch (Exception e) {
            System.debug('VegvesenPointSyncSchedulable: Failed to enqueue queueable: ' + e.getMessage());
        }
    }
}