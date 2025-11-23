/**
 * Mock API Endpoints for Workflows Demo
 * This function provides mock endpoints for order processing workflow
 */

const express = require('express');
const app = express();
app.use(express.json());

// Validation endpoint
app.post('/validate', (req, res) => {
  console.log('=== VALIDATE ORDER ===');
  console.log('Request:', JSON.stringify(req.body, null, 2));
  
  const { order } = req.body;
  
  // Simple validation logic
  const isValid = order && 
                  order.order_id && 
                  order.customer_id && 
                  order.items && 
                  order.items.length > 0 &&
                  order.total > 0;
  
  const response = {
    valid: isValid,
    message: isValid ? 'Order validation passed' : 'Order validation failed - missing required fields'
  };
  
  console.log('Response:', response);
  res.json(response);
});

// Inventory check endpoint
app.post('/inventory', (req, res) => {
  console.log('=== CHECK INVENTORY ===');
  console.log('Request:', JSON.stringify(req.body, null, 2));
  
  const { items } = req.body;
  
  // All items available (in real scenario, would check database)
  const response = {
    available: true,
    items: items.map(item => ({
      product_id: item.product_id,
      requested: item.quantity,
      available: item.quantity,
      in_stock: true
    }))
  };
  
  console.log('Response:', response);
  res.json(response);
});

// Shipping estimate endpoint
app.post('/shipping', (req, res) => {
  console.log('=== SHIPPING ESTIMATE ===');
  console.log('Request:', JSON.stringify(req.body, null, 2));
  
  const { address, items } = req.body;
  
  // Calculate shipping based on state
  const estimatedDays = address.state === 'CA' ? '2-3' : '3-5';
  
  const response = {
    days: estimatedDays,
    cost: 9.99,
    method: 'Ground',
    carrier: 'USPS'
  };
  
  console.log('Response:', response);
  res.json(response);
});

// Tax calculation endpoint
app.post('/tax', (req, res) => {
  console.log('=== CALCULATE TAX ===');
  console.log('Request:', JSON.stringify(req.body, null, 2));
  
  const { total, state } = req.body;
  
  // State tax rates (simplified)
  const taxRates = {
    'CA': 0.0875,  // 8.75%
    'NY': 0.08,    // 8%
    'TX': 0.0625,  // 6.25%
    'FL': 0.06     // 6%
  };
  
  const taxRate = taxRates[state] || 0.07;
  const tax = parseFloat((total * taxRate).toFixed(2));
  
  const response = {
    tax: tax,
    rate: taxRate,
    state: state
  };
  
  console.log('Response:', response);
  res.json(response);
});

// Payment processing endpoint
app.post('/payment', (req, res) => {
  console.log('=== PROCESS PAYMENT ===');
  console.log('Request:', JSON.stringify(req.body, null, 2));
  
  const { order_id, amount, customer_id } = req.body;
  
  // Simulate payment processing
  const response = {
    success: true,
    transaction_id: `TXN-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    amount: amount,
    order_id: order_id,
    status: 'completed',
    timestamp: new Date().toISOString()
  };
  
  console.log('Response:', response);
  res.json(response);
});

// Notification endpoint
app.post('/notification', (req, res) => {
  console.log('=== SEND NOTIFICATION ===');
  console.log('Request:', JSON.stringify(req.body, null, 2));
  
  const { order_id, customer_id, shipping_estimate, total } = req.body;
  
  const response = {
    sent: true,
    order_id: order_id,
    customer_id: customer_id,
    notification_type: 'order_confirmation',
    timestamp: new Date().toISOString()
  };
  
  console.log('Response:', response);
  res.json(response);
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// Export for Cloud Functions
exports.workflowMockApi = app;

// For local testing
if (require.main === module) {
  const port = process.env.PORT || 8080;
  app.listen(port, () => {
    console.log(`Mock API server listening on port ${port}`);
  });
}
