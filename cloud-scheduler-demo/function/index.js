/**
 * Cloud Scheduler Demo Function
 * This function is triggered by Cloud Scheduler every 5 minutes
 */

exports.schedulerHandler = (req, res) => {
  const timestamp = new Date().toISOString();
  const message = `Cloud Scheduler triggered at ${timestamp}`;
  
  console.log('=== SCHEDULED TASK EXECUTION ===');
  console.log(`Timestamp: ${timestamp}`);
  console.log(`Request Method: ${req.method}`);
  console.log(`User-Agent: ${req.get('User-Agent')}`);
  
  // Simulate some work
  console.log('Performing scheduled task...');
  console.log('Task completed successfully!');
  
  // Return success response
  res.status(200).json({
    success: true,
    message: message,
    timestamp: timestamp,
    executedBy: 'Cloud Scheduler'
  });
};
