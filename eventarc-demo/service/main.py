"""
Eventarc Demo - Cloud Run Service
This service receives CloudEvents from Eventarc when files are uploaded to Cloud Storage
"""

import os
import json
from datetime import datetime
from flask import Flask, request

app = Flask(__name__)


@app.route('/', methods=['POST'])
def handle_event():
    """
    Handle CloudEvents from Eventarc
    """
    timestamp = datetime.utcnow().isoformat()
    
    print('=' * 50)
    print('EVENT RECEIVED')
    print('=' * 50)
    print(f'Timestamp: {timestamp}')
    
    # Get CloudEvents headers
    event_type = request.headers.get('ce-type', 'unknown')
    event_id = request.headers.get('ce-id', 'unknown')
    event_source = request.headers.get('ce-source', 'unknown')
    event_time = request.headers.get('ce-time', 'unknown')
    
    print(f'Event Type: {event_type}')
    print(f'Event ID: {event_id}')
    print(f'Event Source: {event_source}')
    print(f'Event Time: {event_time}')
    
    # Parse event data
    try:
        event_data = request.get_json()
        print('\nEvent Data:')
        print(json.dumps(event_data, indent=2))
        
        # Extract file information
        if event_data:
            bucket = event_data.get('bucket', 'unknown')
            file_name = event_data.get('name', 'unknown')
            content_type = event_data.get('contentType', 'unknown')
            size = event_data.get('size', 0)
            time_created = event_data.get('timeCreated', 'unknown')
            
            print('\nFile Details:')
            print(f'Bucket: {bucket}')
            print(f'File Name: {file_name}')
            print(f'Content Type: {content_type}')
            print(f'Size: {size} bytes')
            print(f'Created: {time_created}')
            
            # Simulate file processing based on type
            print('\nProcessing file...')
            
            if content_type.startswith('image/'):
                print('Detected image file - simulating image processing')
                print('- Extracting metadata')
                print('- Generating thumbnail')
                print('- Optimizing for web')
                
            elif content_type.startswith('text/'):
                print('Detected text file - simulating text processing')
                print('- Indexing content')
                print('- Extracting keywords')
                
            elif content_type == 'application/pdf':
                print('Detected PDF file - simulating PDF processing')
                print('- Extracting text')
                print('- Generating preview')
                
            else:
                print(f'Processing generic file of type: {content_type}')
                print('- Storing metadata')
                print('- Running virus scan')
            
            print('\n✓ File processing completed successfully')
            
            response = {
                'status': 'success',
                'message': f'Processed file: {file_name}',
                'bucket': bucket,
                'file': file_name,
                'event_id': event_id,
                'timestamp': timestamp
            }
            
        else:
            print('Warning: No event data received')
            response = {
                'status': 'warning',
                'message': 'No event data received'
            }
    
    except Exception as e:
        print(f'\nERROR: Failed to process event')
        print(f'Error: {str(e)}')
        response = {
            'status': 'error',
            'message': str(e)
        }
    
    print('=' * 50)
    
    return response, 200


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return {'status': 'healthy'}, 200


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
