#!/usr/bin/env node

/**
 * Example usage of WinCC Unified Node.js Client Library
 * Demonstrates basic functionality similar to the Python examples
 */

const { WinCCUnifiedNode } = require('../winccunified-node.js');

// Configuration - get URLs and credentials from environment variables or use defaults
const CONFIG = {
    HTTP_URL: process.env.GRAPHQL_HTTP_URL || 'http://your-wincc-server:4000/graphql',
    WS_URL: process.env.GRAPHQL_WS_URL || 'ws://your-wincc-server:4000/graphql',
    USERNAME: process.env.GRAPHQL_USERNAME || 'username',
    PASSWORD: process.env.GRAPHQL_PASSWORD || 'password'
};

// Utility function to wait for a specified amount of time
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
    console.log('WinCC Unified Node.js Client Example');
    console.log('=' .repeat(40));
    console.log('Note: Please set GRAPHQL_HTTP_URL, GRAPHQL_WS_URL, GRAPHQL_USERNAME, and GRAPHQL_PASSWORD environment variables or update values in the script before running');
    console.log();

    // Initialize client
    const client = new WinCCUnifiedNode(CONFIG.HTTP_URL, CONFIG.WS_URL);
    
    try {
        // Login
        console.log('Logging in...');
        const session = await client.login(CONFIG.USERNAME, CONFIG.PASSWORD);
        console.log(`Logged in as: ${session.user?.name || CONFIG.USERNAME}`);
        console.log(`Token expires: ${session.expires || 'Unknown'}`);
        
        // Get session info
        console.log('\nGetting session info...');
        const sessionInfo = await client.getSession();
        
        if (!sessionInfo || sessionInfo.length === 0) {
            console.log('No session info found');
        } else if (Array.isArray(sessionInfo)) {
            console.log('All sessions info:');
            for (const sInfo of sessionInfo) {
                console.log(`  - User: ${sInfo.user?.fullName || sInfo.user?.name || 'Unknown'}, Expires: ${sInfo.expires || 'Unknown'}`);
            }
        } else {
            console.log('Session info:', sessionInfo);
        }
        
        // Browse available objects
        console.log('\nBrowsing available objects...');
        const objects = await client.browse();
        console.log(`Found ${objects.length} objects`);
        for (const obj of objects.slice(0, 5)) { // Show first 5 objects
            console.log(`  - ${obj.name} (${obj.objectType})`);
        }
        
        // Get tag values
        console.log('\nGetting tag values...');
        const tagNames = ['HMI_Tag_1', 'HMI_Tag_2']; // Replace with actual tag names
        try {
            const tags = await client.getTagValues(tagNames);
            for (const tag of tags) {
                if (tag.error && tag.error.code !== '0') {
                    console.log(`  - ${tag.name}: ERROR - ${tag.error.description}`);
                } else {
                    const value = tag.value?.value;
                    const timestamp = tag.value?.timestamp;
                    const quality = tag.value?.quality?.quality;
                    console.log(`  - ${tag.name}: ${value} (Quality: ${quality}, Time: ${timestamp})`);
                }
            }
        } catch (error) {
            console.log(`Error getting tag values: ${error.message}`);
        }
        
        // Get logged tag values
        console.log('\nGetting logged tag values...');
        try {
            // Get values from the last 24 hours
            const endTime = new Date();
            const startTime = new Date(endTime.getTime() - 24 * 60 * 60 * 1000);
            
            const loggedValues = await client.getLoggedTagValues(
                ['PV-Vogler-PC::Meter_Input_WattAct:LoggingTag_1'],
                startTime.toISOString(),
                endTime.toISOString(),
                10
            );
            
            console.log(`Found ${loggedValues.length} logged tag results`);
            for (const result of loggedValues) {
                if (result.error && result.error.code !== '0') {
                    console.log(`  - ${result.loggingTagName}: ERROR - ${result.error.description}`);
                } else {
                    const values = result.values || [];
                    console.log(`  - ${result.loggingTagName}: ${values.length} values`);
                    for (const value of values.slice(-5)) { // Show last 5 values
                        const timestamp = value.value?.timestamp;
                        const val = value.value?.value;
                        const quality = value.value?.quality?.quality;
                        console.log(`    ${timestamp}: ${val} (Quality: ${quality})`);
                    }
                }
            }
        } catch (error) {
            console.log(`Error getting logged tag values: ${error.message}`);
        }
        
        // Get active alarms
        console.log('\nGetting active alarms...');
        try {
            const alarms = await client.getActiveAlarms();
            console.log(`Found ${alarms.length} active alarms`);
            for (const alarm of alarms.slice(0, 3)) { // Show first 3 alarms
                const eventText = Array.isArray(alarm.eventText) ? alarm.eventText.join(', ') : alarm.eventText;
                console.log(`  - ${alarm.name}: ${eventText} (Priority: ${alarm.priority})`);
            }
        } catch (error) {
            console.log(`Error getting alarms: ${error.message}`);
        }
        
        // Example of writing tag values
        console.log('\nWriting tag values...');
        try {
            const writeResult = await client.writeTagValues([
                { name: 'HMI_Tag_1', value: 100 },
                { name: 'HMI_Tag_2', value: 200 }
            ]);
            
            for (const result of writeResult) {
                if (result.error) {
                    console.log(`  - ${result.name}: ERROR - ${result.error.description}`);
                } else {
                    console.log(`  - ${result.name}: Written successfully`);
                }
            }
        } catch (error) {
            console.log(`Error writing tag values: ${error.message}`);
        }
        
        // Set up subscription for tag values
        console.log('\nSetting up tag value subscription...');
        let tagSubscription = null;
        
        try {
            const onTagData = (data) => {
                const value = data.value?.value;
                const timestamp = data.value?.timestamp;
                const reason = data.notificationReason || 'UPDATE';
                console.log(`  [SUBSCRIPTION] ${data.name}: ${value} (${reason}) at ${timestamp}`);
            };
            
            const onTagError = (error) => {
                console.log(`  [SUBSCRIPTION ERROR] ${error.message || error}`);
            };
            
            const onTagComplete = () => {
                console.log('  [SUBSCRIPTION] Tag subscription completed');
            };
            
            tagSubscription = await client.subscribeToTagValues(
                tagNames,
                onTagData,
                onTagError,
                onTagComplete
            );
            
            console.log('Tag subscription active. Waiting for updates...');
            
            // Keep subscription active for 30 seconds
            await sleep(30000);
            
            // Unsubscribe
            console.log('Unsubscribing from tag values...');
            if (tagSubscription && tagSubscription.unsubscribe) {
                tagSubscription.unsubscribe();
            }
            
        } catch (error) {
            console.log(`Error setting up subscription: ${error.message}`);
        }
        
        // Set up subscription for active alarms
        console.log('\nSetting up alarm subscription...');
        let alarmSubscription = null;
        
        try {
            const onAlarmData = (data) => {
                const alarmData = data.data;
                if (alarmData?.activeAlarms) {
                    const alarms = Array.isArray(alarmData.activeAlarms) ? alarmData.activeAlarms : [alarmData.activeAlarms];
                    for (const alarm of alarms) {
                        const reason = alarm.notificationReason || 'UPDATE';
                        const eventText = Array.isArray(alarm.eventText) ? alarm.eventText.join(', ') : alarm.eventText;
                        console.log(`  [ALARM] ${alarm.name}: ${eventText} (${reason})`);
                    }
                }
            };
            
            const onAlarmError = (error) => {
                console.log(`  [ALARM ERROR] ${error.message || error}`);
            };
            
            const onAlarmComplete = () => {
                console.log('  [ALARM] Alarm subscription completed');
            };
            
            alarmSubscription = await client.subscribeToActiveAlarms(
                onAlarmData,
                onAlarmError,
                onAlarmComplete
            );
            
            console.log('Alarm subscription active. Waiting for updates...');
            
            // Keep subscription active for 30 seconds
            await sleep(30000);
            
            // Unsubscribe
            console.log('Unsubscribing from alarms...');
            if (alarmSubscription && alarmSubscription.unsubscribe) {
                alarmSubscription.unsubscribe();
            }
            
        } catch (error) {
            console.log(`Error setting up alarm subscription: ${error.message}`);
        }
        
        // Logout
        console.log('\nLogging out...');
        await client.logout();
        console.log('Logged out successfully');
        
    } catch (error) {
        console.error(`Error: ${error.message}`);
        console.error('Stack trace:', error.stack);
    } finally {
        // Cleanup
        if (client.dispose) {
            client.dispose();
        }
    }
}

// Graceful shutdown handling
const gracefulShutdown = (signal) => {
    console.log(`\nReceived ${signal}, shutting down gracefully...`);
    process.exit(0);
};

// Handle shutdown signals
process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
    console.error(`Uncaught Exception:`, error);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error(`Unhandled Rejection at:`, promise, 'reason:', reason);
    process.exit(1);
});

// Run if this file is executed directly
if (require.main === module) {
    main();
}

// Export for use in other modules
module.exports = {
    main,
    CONFIG
};