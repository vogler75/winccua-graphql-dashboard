// Scripting Test - HMI Tag Oscillator
// Demonstrates tag writing using WinCC Unified Node.js library

const { WinCCUnifiedNode } = require('../winccunified-node.js');

// Configuration
const CONFIG = {
    // GraphQL server endpoints
    httpUrl: 'http://DESKTOP-KHLB071:4000/graphql',
    wsUrl: 'ws://DESKTOP-KHLB071:4000/graphql',
    
    // Tag configuration
    tagName: 'HMI_Tag_1',
    minValue: 1,
    maxValue: 1000,
    interval: 10000, // 10 seconds
    
    // Authentication (required for GraphQL server)
    username: 'username1',
    password: 'password1'
};

// HMI Tag Oscillator using WinCC Unified Node.js library
async function startTagOscillator() {
    let currentValue = CONFIG.minValue;
    let direction = 1; // 1 for increasing, -1 for decreasing
    
    // Create WinCC Unified client
    const client = new WinCCUnifiedNode(CONFIG.httpUrl, CONFIG.wsUrl);
    
    // Login to GraphQL server
    try {
        console.log('🔐 Authenticating with GraphQL server...');
        const session = await client.login(CONFIG.username, CONFIG.password);
        console.log(`✅ Authentication successful - User: ${session.user?.name || CONFIG.username}`);
        console.log(`🎫 Session token expires: ${session.expires || 'Unknown'}`);
    } catch (error) {
        console.error('❌ Authentication failed:', error.message);
        throw error;
    }
    
    const updateTag = async () => {
        try {
            // Use the writeTagValues method from the library
            const result = await client.writeTagValues([
                {
                    name: CONFIG.tagName,
                    value: currentValue
                }
            ]);
            
            if (result && result[0]?.error) {
                console.error(`[${new Date().toISOString()}] ${CONFIG.tagName} write error:`, result[0].error.description);
                
                // Check if it's an authentication error and try to re-login
                if (result[0].error.code === 'UNAUTHORIZED' || result[0].error.description.includes('authentication')) {
                    console.log('🔄 Re-authenticating due to authentication error...');
                    try {
                        await client.login(CONFIG.username, CONFIG.password);
                        console.log('✅ Re-authentication successful');
                    } catch (loginError) {
                        console.error('❌ Re-authentication failed:', loginError.message);
                    }
                }
            } else {
                console.log(`[${new Date().toISOString()}] ${CONFIG.tagName} updated to: ${currentValue}`);
            }
        } catch (error) {
            console.error(`[${new Date().toISOString()}] Error updating ${CONFIG.tagName}:`, error.message);
            
            // Check if it's an authentication error and try to re-login
            if (error.message.includes('authentication') || error.message.includes('unauthorized')) {
                console.log('🔄 Re-authenticating due to connection error...');
                try {
                    await client.login(CONFIG.username, CONFIG.password);
                    console.log('✅ Re-authentication successful');
                } catch (loginError) {
                    console.error('❌ Re-authentication failed:', loginError.message);
                }
            }
        }
        
        // Update value for next iteration
        currentValue += direction;
        
        // Change direction at boundaries
        if (currentValue >= CONFIG.maxValue) {
            direction = -1;
        } else if (currentValue <= CONFIG.minValue) {
            direction = 1;
        }
    };
    
    // Run every configured interval
    const intervalId = setInterval(updateTag, CONFIG.interval);
    
    // Run immediately on start
    updateTag();
    
    console.log(`🔄 ${CONFIG.tagName} oscillator started (${CONFIG.minValue}-${CONFIG.maxValue} every ${CONFIG.interval/1000} seconds)`);
    
    // Return function to stop the oscillator
    return () => {
        clearInterval(intervalId);
        client.dispose();
        console.log(`🛑 ${CONFIG.tagName} oscillator stopped`);
    };
}

// Graceful shutdown handling
const gracefulShutdown = (signal) => {
    console.log(`\n🛑 Received ${signal}, shutting down gracefully...`);
    if (stopOscillator) {
        stopOscillator();
    }
    process.exit(0);
};

// Global reference to stop function
let stopOscillator = null;

// Main execution
async function main() {
    try {
        console.log('='.repeat(60));
        console.log('🚀 HMI Tag Oscillator Test Started');
        console.log('='.repeat(60));
        console.log(`📊 Target Server: ${CONFIG.httpUrl}`);
        console.log(`🏷️  Tag Name: ${CONFIG.tagName}`);
        console.log(`📈 Value Range: ${CONFIG.minValue} - ${CONFIG.maxValue}`);
        console.log(`⏱️  Interval: ${CONFIG.interval/1000} seconds`);
        console.log('='.repeat(60));
        
        // Start the oscillator (includes authentication)
        stopOscillator = await startTagOscillator();
        
    } catch (error) {
        console.error('❌ Failed to start oscillator:', error.message);
        process.exit(1);
    }
}

// Handle shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
    console.error(`[${new Date().toISOString()}] Uncaught Exception:`, error);
    if (stopOscillator) {
        stopOscillator();
    }
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error(`[${new Date().toISOString()}] Unhandled Rejection at:`, promise, 'reason:', reason);
    if (stopOscillator) {
        stopOscillator();
    }
    process.exit(1);
});

// Run if this file is executed directly
if (require.main === module) {
    main();
}

// Export for use in other modules
module.exports = {
    startTagOscillator,
    CONFIG
};