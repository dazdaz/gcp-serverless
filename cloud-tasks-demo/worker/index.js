/**
 * Cloud Tasks Demo - Worker Function
 * This function processes tasks from the Cloud Tasks queue
 */

exports.taskHandler = async (req, res) => {
  const timestamp = new Date().toISOString();
  
  console.log('=== TASK RECEIVED ===');
  console.log(`Timestamp: ${timestamp}`);
  console.log(`Request Method: ${req.method}`);
  
  // Extract task information from headers
  const taskName = req.get('X-CloudTasks-TaskName') || 'unknown';
  const queueName = req.get('X-CloudTasks-QueueName') || 'unknown';
  const retryCount = req.get('X-CloudTasks-TaskRetryCount') || '0';
  const executionCount = req.get('X-CloudTasks-TaskExecutionCount') || '1';
  
  console.log(`Task Name: ${taskName}`);
  console.log(`Queue: ${queueName}`);
  console.log(`Retry Count: ${retryCount}`);
  console.log(`Execution Count: ${executionCount}`);
  
  // Parse task payload
  let taskData;
  try {
    taskData = req.body;
    console.log('Task Payload:', JSON.stringify(taskData, null, 2));
  } catch (error) {
    console.error('Failed to parse task payload:', error);
    return res.status(400).json({ error: 'Invalid task payload' });
  }
  
  // Simulate task processing
  try {
    console.log('Processing task...');
    
    // Simulate different task types
    if (taskData.operation === 'resize') {
      console.log(`Resizing image ${taskData.image_id} to ${taskData.dimensions.width}x${taskData.dimensions.height}`);
      // Simulate processing time
      await new Promise(resolve => setTimeout(resolve, 1000));
      console.log('Image resized successfully');
      
    } else if (taskData.operation === 'thumbnail') {
      console.log(`Creating thumbnail for ${taskData.image_id}`);
      await new Promise(resolve => setTimeout(resolve, 500));
      console.log('Thumbnail created successfully');
      
    } else if (taskData.operation === 'fail') {
      // Simulate failure for testing retry logic
      throw new Error('Simulated task failure for testing');
      
    } else {
      console.log(`Processing generic task: ${taskData.operation || 'unknown'}`);
      await new Promise(resolve => setTimeout(resolve, 500));
      console.log('Task processed successfully');
    }
    
    console.log('=== TASK COMPLETED ===');
    
    // Return success response
    res.status(200).json({
      success: true,
      message: 'Task processed successfully',
      taskName: taskName,
      timestamp: timestamp,
      retryCount: parseInt(retryCount),
      data: taskData
    });
    
  } catch (error) {
    console.error('=== TASK FAILED ===');
    console.error('Error:', error.message);
    
    // Return error status to trigger retry
    res.status(500).json({
      success: false,
      error: error.message,
      taskName: taskName,
      timestamp: timestamp,
      retryCount: parseInt(retryCount)
    });
  }
};
