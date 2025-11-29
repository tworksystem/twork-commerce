/**
 * WooCommerce Webhook Server
 * Sends FCM notifications when order status changes
 * 
 * Setup:
 * 1. npm install express firebase-admin body-parser
 * 2. Configure Firebase Admin SDK (see below)
 * 3. Run: node webhook_server.js
 * 
 * WooCommerce Configuration:
 * - Webhook URL: http://your-server.com/api/webhook/order-status
 * - Secret Key: Your secret key
 * - Status: Active
 */

const express = require('express');
const admin = require('firebase-admin');
const bodyParser = require('body-parser');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(bodyParser.json());

// Initialize Firebase Admin SDK
// IMPORTANT: Replace with your service account key
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

/**
 * Database: In-memory storage for FCM tokens
 * Replace this with your actual database (MongoDB, MySQL, etc.)
 */
const userTokens = new Map();

/**
 * API: Register/Update FCM Token
 * POST /api/users/register-token
 * Body: { userId: string, fcmToken: string, platform: string }
 */
app.post('/api/users/register-token', async (req, res) => {
  try {
    const { userId, fcmToken, platform } = req.body;

    if (!userId || !fcmToken) {
      return res.status(400).json({
        success: false,
        error: 'userId and fcmToken are required',
      });
    }

    // Store token in database
    if (!userTokens.has(userId)) {
      userTokens.set(userId, []);
    }
    
    const tokens = userTokens.get(userId);
    
    // Remove old tokens and add new one
    const filteredTokens = tokens.filter(
      token => token.platform !== platform || token.token !== fcmToken
    );
    filteredTokens.push({ token: fcmToken, platform: platform || 'android' });
    userTokens.set(userId, filteredTokens);

    console.log(`✅ FCM token registered for user ${userId}: ${fcmToken.substring(0, 20)}...`);

    res.json({
      success: true,
      message: 'FCM token registered successfully',
      userId: userId,
      tokenCount: filteredTokens.length,
    });
  } catch (error) {
    console.error('❌ Error registering token:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * Webhook: WooCommerce Order Status Change
 * POST /api/webhook/order-status
 * This is called by WooCommerce when order status changes
 */
app.post('/api/webhook/order-status', async (req, res) => {
  try {
    const order = req.body;

    // Validate webhook payload
    if (!order || !order.id) {
      console.error('❌ Invalid webhook payload');
      return res.status(400).json({
        success: false,
        error: 'Invalid order data',
      });
    }

    console.log(`📦 Order status webhook received: Order #${order.id}, Status: ${order.status}`);

    // Get customer ID from order
    const customerId = order.customer_id?.toString();
    
    if (!customerId) {
      console.error('❌ No customer ID in order');
      return res.status(400).json({
        success: false,
        error: 'No customer ID found',
      });
    }

    // Get FCM tokens for this customer
    const tokens = userTokens.get(customerId) || [];
    
    if (tokens.length === 0) {
      console.log(`⚠️ No FCM tokens found for customer ${customerId}`);
      return res.json({
        success: true,
        message: 'No tokens to send notification to',
      });
    }

    // Prepare notification
    const statusMessage = getStatusMessage(order.status);
    const total = order.total || '0.00';
    const currency = order.currency || 'USD';

    const notification = {
      title: `Order #${order.id} ${statusMessage}`,
      body: `Your order total is ${currency} ${total}`,
    };

    const data = {
      orderId: order.id.toString(),
      status: order.status,
      total: order.total?.toString() || '0',
      currency: order.currency || 'USD',
      type: 'order_status_update',
    };

    // Send notification to all tokens for this user with retry logic
    const results = [];
    const MAX_RETRIES = 3;
    const RETRY_DELAY = 1000; // 1 second
    
    for (const { token, platform } of tokens) {
      let retryCount = 0;
      let success = false;
      
      while (retryCount < MAX_RETRIES && !success) {
        try {
          const message = {
            token: token,
            notification: notification,
            data: data,
            // Add time-to-live for better delivery
            android: {
              priority: 'high',
              ttl: 3600000, // 1 hour
              notification: {
                channelId: 'order_updates',
                sound: 'default',
                priority: 'high',
                importance: 'high',
                // Enable heads-up notification
                defaultSound: true,
                defaultVibrateTimings: true,
                defaultLightSettings: true,
              },
            },
            apns: {
              headers: {
                'apns-priority': '10', // High priority
              },
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                  // Enable critical alert for important updates
                  alert: {
                    title: notification.title,
                    body: notification.body,
                  },
                  'content-available': 1, // Enable background processing
                },
              },
            },
            // Add web push config for better delivery
            webpush: {
              notification: {
                title: notification.title,
                body: notification.body,
                requireInteraction: true, // Keep notification visible
              },
            },
          };

          const response = await admin.messaging().send(message);
          console.log(`✅ Notification sent to ${platform} token: ${token.substring(0, 20)}...`);
          
          results.push({
            platform: platform,
            success: true,
            messageId: response,
            retries: retryCount,
          });
          
          success = true;
        } catch (error) {
          retryCount++;
          
          // Remove invalid tokens immediately (don't retry)
          if (error.code === 'messaging/invalid-registration-token' || 
              error.code === 'messaging/registration-token-not-registered') {
            console.error(`❌ Invalid token detected, removing: ${token.substring(0, 20)}...`);
            const updatedTokens = tokens.filter(t => t.token !== token);
            userTokens.set(customerId, updatedTokens);
            
            results.push({
              platform: platform,
              success: false,
              error: error.code || error.message,
              retries: retryCount - 1,
            });
            
            break; // Don't retry invalid tokens
          }
          
          // Retry on temporary errors
          if (retryCount < MAX_RETRIES) {
            console.warn(`⚠️ Retry ${retryCount}/${MAX_RETRIES} for token ${token.substring(0, 20)}...: ${error.code}`);
            await new Promise(resolve => setTimeout(resolve, RETRY_DELAY * retryCount)); // Exponential backoff
          } else {
            console.error(`❌ Failed to send notification after ${MAX_RETRIES} retries to token ${token.substring(0, 20)}...:`, error.code);
            
            results.push({
              platform: platform,
              success: false,
              error: error.code || error.message,
              retries: retryCount,
            });
          }
        }
      }
    }

    console.log(`📤 Sent ${results.filter(r => r.success).length}/${results.length} notifications for order #${order.id}`);

    // Always return success to WooCommerce (even if some notifications failed)
    res.json({
      success: true,
      message: 'Webhook processed',
      orderId: order.id,
      notificationsSent: results.filter(r => r.success).length,
      results: results,
    });
  } catch (error) {
    console.error('❌ Error processing webhook:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * Helper: Get user-friendly status message
 */
function getStatusMessage(status) {
  const statusMap = {
    'pending': 'is being processed',
    'processing': 'is being prepared',
    'on-hold': 'is on hold',
    'completed': 'has been completed',
    'cancelled': 'has been cancelled',
    'refunded': 'has been refunded',
    'failed': 'payment failed',
    'shipped': 'has been shipped',
  };
  
  return statusMap[status] || 'status has been updated';
}

/**
 * API: Get stored tokens (for debugging)
 * GET /api/debug/tokens
 */
app.get('/api/debug/tokens', (req, res) => {
  const debugInfo = {};
  userTokens.forEach((tokens, userId) => {
    debugInfo[userId] = tokens.map(t => ({
      platform: t.platform,
      token: t.token.substring(0, 30) + '...',
    }));
  });
  
  res.json({
    userCount: userTokens.size,
    tokens: debugInfo,
  });
});

/**
 * API: Health check
 * GET /api/health
 */
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    registeredUsers: userTokens.size,
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Webhook server running on port ${PORT}`);
  console.log(`📦 WooCommerce webhook URL: http://your-server.com:${PORT}/api/webhook/order-status`);
  console.log(`📱 FCM registration URL: http://your-server.com:${PORT}/api/users/register-token`);
});

/**
 * Firebase Admin Service Account Setup:
 * 
 * 1. Go to Firebase Console → Project Settings → Service Accounts
 * 2. Click "Generate new private key"
 * 3. Save as serviceAccountKey.json in this directory
 * 4. Make sure to add serviceAccountKey.json to .gitignore
 * 
 * File structure should be:
 * backend/
 *   ├── webhook_server.js
 *   ├── serviceAccountKey.json
 *   └── package.json
 */

