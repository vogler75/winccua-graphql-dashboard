const express = require('express');
const path = require('path');
const { createServer } = require('http');
const httpProxy = require('http-proxy');

const app = express();
const server = createServer(app);
const proxy = httpProxy.createProxyServer({ target: 'http://DESKTOP-KHLB071:4000', ws: true });


// Configuration
const PORT = 8080;

// Enable CORS for all routes
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
    
    if (req.method === 'OPTIONS') {
        res.sendStatus(200);
    } else {
        next();
    }
});

// Serve static files (dashboard)
app.use(express.static(path.join(__dirname)));

// Health check endpoint
app.get('/health', async (req, res) => {
    const health = {
        status: 'ok', 
        timestamp: new Date().toISOString(),
        server: 'Static file server'
    };

    res.json(health);
});

// Default route - serve dashboard
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'dashboard.html'));
});

// Proxy POST requests to GraphQL endpoint
app.post('/graphql', function(req, res) {    
    //console.log(`[${new Date().toISOString()}] Proxy POST request for: ${req.url}`);
    proxy.web(req, res, {});
});

// Proxy WebSocket requests to GraphQL WS endpoint
server.on('upgrade', function (req, socket, head) {    
    if (req.url == '/graphql') {
        //console.log(`[${new Date().toISOString()}] Proxy Upgrade request for: ${req.url}`);        
        try {
            proxy.ws(req, socket, head);
        } catch (error) {
            console.error(`[${new Date().toISOString()}] WebSocket proxy error:`, error);
            socket.write('HTTP/1.1 500 Internal Server Error\r\n\r\n');
            socket.destroy();
        }
    } 
    else 
    {
        // For non-/graphql upgrade requests, handle with default HTTP 426 response (Upgrade Required)
        socket.write('HTTP/1.1 426 Upgrade Required\r\n\r\n');
        socket.destroy();
    }
});

// Error handling middleware
app.use((error, req, res, next) => {
    console.error(`[${new Date().toISOString()}] Server error:`, error);
    res.status(500).json({ error: 'Internal server error' });
});

// Global error handlers
process.on('uncaughtException', (error) => {
    console.error(`[${new Date().toISOString()}] Uncaught Exception:`, error);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error(`[${new Date().toISOString()}] Unhandled Rejection at:`, promise, 'reason:', reason);
});

// Start server with error handling
server.listen(PORT, (error) => {
    if (error) {
        console.error(`[${new Date().toISOString()}] Failed to start server:`, error);
        process.exit(1);
    }
    
    console.log('='.repeat(60));
    console.log('🚀 Static File Server Started');
    console.log('='.repeat(60));
    console.log(`📊 Dashboard URL: http://localhost:${PORT}`);
    console.log(`🔗 Health Check: http://localhost:${PORT}/health`);
    console.log(`🔗 GraphQL Endpoint: http://localhost:${PORT}/graphql`)
    console.log(`🔗 WebSocket Endpoint: ws://localhost:${PORT}/graphql`);
    console.log('='.repeat(60));
    console.log('Ready to accept connections...');
});

// Handle server errors
server.on('error', (error) => {
    if (error.code === 'EADDRINUSE') {
        console.error(`[${new Date().toISOString()}] Port ${PORT} is already in use`);
        process.exit(1);
    } else {
        console.error(`[${new Date().toISOString()}] Server error:`, error);
    }
});

// Graceful shutdown
const gracefulShutdown = (signal) => {
    console.log(`\n🛑 Received ${signal}, shutting down gracefully...`);
    
    // Close HTTP server (this will also close WebSocket connections)
    server.close(() => {
        console.log('✅ Server closed successfully');
        process.exit(0);
    });
    
    // Force exit after 10 seconds
    setTimeout(() => {
        console.log('⚠️  Forced shutdown');
        process.exit(1);
    }, 10000);
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));