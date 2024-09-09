**GlobalPartners**

Data Ingestion process using AWS Lambda to pull weather data from the Open-Meteo API and store it in an S3 bucket
  - Create two **S3** buckets one for raw data nd one for cleaned data.
  - Create a **SNS Topic** and **subscription** for sending alerts if data fetch fails.
  - Create an **IAM Role**, **The Lambda** function will need an IAM role with permissions to access the S3 buckets and publish messages to       an SNS topic.
    Lambda pulls the data from API stores the raw data into S3 bucket1 and performs cleaning operaion and stores the data in S3 bucket2.

Fetch Raw Data:
Retrieving weather data from the Open-Meteo API for each city.
Validating the response; sending an SNS alert if data retrieval fails.

Storing Raw Data:
Convert the API response into JSON.
Uploading the raw JSON data to the RAW_BUCKET_NAME S3 bucket (bucket1).

Process the Data:
Extracting relevant information (e.g., city, state, temperature, precipitation).
Computing daily summaries, such as highest/lowest temperature and rainfall status.

Store Processed Data:
Converting the cleaned data to JSON format.
Uploading the processed data to the CLEANED_BUCKET_NAME S3 bucket (bucket2).

Cleanup:
Delete any existing data with the same key(if data of a certain date already present) in the S3 buckets before uploading new data.

Return:
Return a success message after processing all locations.

Maintaining Data Quality
- API Response Validation Ensuring the status code is 200.
- Data consistency checks, comparing data trends and spike that could indicate an issues related to data source.
- Duplication checks, making sure duplicate records are not being stored.
- Seting up AWS CloudWatch to monitor the execution of Lambda functions, tracking metrics such as execution time, error rates, and data        processing counts. Configure alarms to trigger notifications if anomalies are detected (e.g., higher than expected error rates).
- SNS alerts, setting up with Lambda Function to alert when data retrieval fails.

Scalability and Resilience
- API scaling, Implementing rate limiting when making API requests ensures that external services (API Provider) are not overwhelmed. This prevents data loss and API bans during high load periods.
- Organizing data using well-structured prefixes and object naming conventions (based on date and city) ensures efficient retrieval and storage, which is important as the volume of data grows.
- Lambda functions, S3, SNS, and other AWS services are typically deployed across multiple Availability Zones (AZs), ensuring that the system remains operational even if one AZ fails.
- Using S3 cross-region replication (CRR) ensures that data is replicated to another region, protecting against regional failures.

Integrating with SnowFlake and DBT.
- Using Snowflake as a cloud data warehouse to store the processed data for querying and analytics would be much handy and efficient. Snowflake's integration with S3 as a data source and also helps in using external stages to ingest data directly from S3 into Snowflake tables.
- Uning DBT to transform the raw data stored in Snowflake into meaningful insights. dbt operates on top of Snowflake and helps in enabling version-controlled, SQL-based transformations.

Optimizing data flow from S3 to Snowflake
- Dynamic Scaling: Adjusting the Snowflake’s virtual warehouses for handling varying loads, improving performance and cost-efficiency during heavy traffic / peak ingestion periods.
- Compressing the files and partition data logically based on time intervals or other attributes to to reduce storage costs and speed up data loads.
- Processing the data in batches, Optimize for large datasets by batching loads using the COPY INTO command. This approach reduces load frequency and maximizes throughput.
- Automating the data loading process from S3 into Snowflake in near real-time using **Snowpipe**, eliminating manual intervention and ensuring data availability as soon as it's ingested.

Data Access and Exposure
- Role based access control, giving relevant data access based on their role.
- Masking certain rows of the data or Row level security helps in limiting the access to certain columns or rows for specific users.
- Choosing the right size for the warehouse based on the workload helps in saving the cloud billing.
- Auto-suspending for virtual warehouses to automatically shut down during inactivity, minimizing costs, and using auto-resume to restart when new queries arrive.
