import os
import json
import requests
import boto3
from datetime import datetime, timezone

BASE_URL = "https://api.open-meteo.com/v1/forecast"
# s3 buckets
RAW_BUCKET_NAME = os.environ['RAW_BUCKET_NAME']
CLEANED_BUCKET_NAME = os.environ['CLEANED_BUCKET_NAME']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']  

LOCATIONS = [
    {"city": "New York", "state": "NY", "latitude": 40.7128, "longitude": -74.0060},
    {"city": "Los Angeles", "state": "CA", "latitude": 34.0522, "longitude": -118.2437},
    {"city": "Chicago", "state": "IL", "latitude": 41.8781, "longitude": -87.6298},
    {"city": "Houston", "state": "TX", "latitude": 29.7604, "longitude": -95.3698},
    {"city": "Phoenix", "state": "AZ", "latitude": 33.4484, "longitude": -112.0740},
    {"city": "Miami", "state": "FL", "latitude": 25.7617, "longitude": -80.1918},
    {"city": "Seattle", "state": "WA", "latitude": 47.6062, "longitude": -122.3321},
    {"city": "Denver", "state": "CO", "latitude": 39.7392, "longitude": -104.9903},
    {"city": "Boston", "state": "MA", "latitude": 42.3601, "longitude": -71.0589},
    {"city": "San Francisco", "state": "CA", "latitude": 37.7749, "longitude": -122.4194}
]

def lambda_handler(event, context):
    # Define the file names using today's date
    today = datetime.now(timezone.utc).strftime('%Y-%m-%d')

    # Initialize the S3 client
    s3 = boto3.client('s3')
    sns = boto3.client('sns')

    # Process each location separately
    for location in LOCATIONS:
        latitudes = str(location['latitude'])
        longitudes = str(location['longitude'])

        params = {
            "latitude": latitudes,
            "longitude": longitudes,
            "hourly": "temperature_2m,precipitation",
            "forecast_days": "1"
        }

        response = requests.get(BASE_URL, params=params)
        if response.status_code != 200:
            # Send SNS notification on failure
            error_message = f"Failed to fetch weather data for {location['city']}, {location['state']}."
            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Message=error_message,
                Subject="Weather Data Fetch Error"
            )
            return {
                'statusCode': 500,
                'body': error_message
            }
        
        raw_data = response.json()
        raw_data['city'] = location['city']
        raw_data['state'] = location['state']

        if raw_data:
            # Convert raw_data to JSON format
            raw_data_json = json.dumps(raw_data)
            
            # Check if the prefix exists in the raw S3 bucket and delete if exists
            raw_key = f"weather_data/{today}/{location['city']}_raw.json"
            if s3.list_objects(Bucket=RAW_BUCKET_NAME, Prefix=raw_key).get('Contents'):
                s3.delete_object(Bucket=RAW_BUCKET_NAME, Key=raw_key)
                print(f"Deleted existing raw data for {location['city']} from S3 bucket '{RAW_BUCKET_NAME}'.")

            # Upload raw data to the raw S3 bucket
            s3.put_object(Body=raw_data_json, Bucket=RAW_BUCKET_NAME, Key=raw_key)
            print(f"Raw weather data for {location['city']} successfully saved to S3 bucket '{RAW_BUCKET_NAME}'.")

            # Perform data cleaning and generate the cleaned data
            city = raw_data['city']
            state = raw_data['state']
            temp = raw_data['hourly']['temperature_2m'][0]  # Assuming hourly data is available
            precip = raw_data['hourly']['precipitation'][0]  # Assuming hourly data is available

            # Save cleaned data directly
            cleaned_data = {
                'city': city,
                'state': state,
                'highest_temp': temp,  # Update logic as needed
                'lowest_temp': temp,    # Update logic as needed
                'rainfall_status': 'Yes' if precip > 0 else 'No'
            }

            print(cleaned_data)

            # Convert cleaned_data to JSON format
            cleaned_data_json = json.dumps(cleaned_data)
            
            # Check if the prefix exists in the cleaned S3 bucket and delete if exists
            cleaned_key = f"weather_data/{today}/{city}_cleaned.json"
            if s3.list_objects(Bucket=CLEANED_BUCKET_NAME, Prefix=cleaned_key).get('Contents'):
                s3.delete_object(Bucket=CLEANED_BUCKET_NAME, Key=cleaned_key)
                print(f"Deleted existing cleaned data for {city} from S3 bucket '{CLEANED_BUCKET_NAME}'.")

            # Upload JSON to the cleaned S3 bucket
            s3.put_object(Body=cleaned_data_json, Bucket=CLEANED_BUCKET_NAME, Key=cleaned_key)
            print(f"Cleaned weather data for {city} successfully saved to S3 bucket '{CLEANED_BUCKET_NAME}'.")

    # Return statement moved outside the loop
    return {
        'statusCode': 200,
        'body': "Raw and cleaned weather data successfully saved."
    }
