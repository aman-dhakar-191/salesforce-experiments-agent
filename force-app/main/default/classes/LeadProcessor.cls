/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : LeadProcessor
 * Author          : <YourName>
 * Created Date    : Aug 13, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Aug 13, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Aug 13, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

global class LeadProcessor implements Database.Batchable<SObject>, Database.Stateful {
	global Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator([SELECT Id, LeadSource FROM Lead]);
	}

	global void execute(Database.BatchableContext bc, List<Lead> scope) {
		for (Lead l : scope) {
            l.LeadSource = 'Dreamforce';
        }
        update scope;
	}

	global void finish(Database.BatchableContext bc) {
		// No post-processing
	}
}