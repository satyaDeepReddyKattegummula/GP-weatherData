provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "raw_weather_s3_bucket" {
  bucket = var.raw_data_bucket_name
}

resource "aws_s3_bucket" "cleaned_weather_s3_bucket" {
  bucket = var.cleaned_data_bucket_name
}

resource "aws_sns_topic" "email_alert" {
  name = var.sns-topic-name
}

resource "aws_sns_topic_subscription" "weather_data_notification" {
  
  depends_on = [ 
    aws_sns_topic.email_alert,
    aws_s3_bucket.cleaned_weather_s3_bucket,
    aws_s3_bucket.raw_weather_s3_bucket ]

  topic_arn = aws_sns_topic.email_alert.arn
  protocol = "email"
  endpoint = var.sns-email
}

resource "aws_iam_role" "lambda_weather_role" {
  name = var.lambda_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "lambda_weather_policy" {
  name = var.Lambda_policy_name
  role = aws_iam_role.lambda_weather_role.id
  
  depends_on = [ 
    aws_s3_bucket.raw_weather_s3_bucket,
    aws_s3_bucket.cleaned_weather_s3_bucket 
  ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sns:Publish",
          "log:*"
        ],
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.raw_weather_s3_bucket.arn}/*",
          "${aws_s3_bucket.cleaned_weather_s3_bucket.arn}/*"
        ]
      },
      {
        Action = [
          "s3:ListBucket"
        ]
        Effect = "Allow",
        Resource = [
          "${aws_s3_bucket.raw_weather_s3_bucket.arn}",
          "${aws_s3_bucket.cleaned_weather_s3_bucket.arn}"
        ]
      },

    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role = aws_iam_role.lambda_weather_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "weather_lambda_function" {
  function_name = var.lambda_function_name
  filename = "lambda_function.zip"
  role = aws_iam_role.lambda_weather_role.arn
  handler = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256("lambda_function.zip")
  runtime = "python3.12"
  timeout = 10

  environment {
    variables = {
      RAW_BUCKET_NAME = aws_s3_bucket.raw_weather_s3_bucket.bucket
      CLEANED_BUCKET_NAME = aws_s3_bucket.cleaned_weather_s3_bucket.bucket
      SNS_TOPIC_ARN = aws_sns_topic.email_alert.arn

    }
  }

  depends_on = [ aws_sns_topic.email_alert,]
}


module "eventbridge" {
  
  depends_on = [ aws_lambda_function.weather_lambda_function ]
  
  source = "terraform-aws-modules/eventbridge/aws"
  bus_name = "Trigger_weather_lambda_event_bus"
  attach_lambda_policy = true
  lambda_target_arns   = [aws_lambda_function.weather_lambda_function.arn]

  schedules = {
    lambda-cron = {
      description         = "Trigger the Lambda everyday at 5 AM"
      schedule_expression = "cron(0 11 * * ? *)"
      timezone            = "America/Chicago"
      arn                 = aws_lambda_function.weather_lambda_function.arn
      input               = jsonencode({ "job" : "cron-by-rate" })
    }
  }
}


output "Email_notification_will_be_sent_to" {
  value = var.sns-email
  description = "Email notification will be sent to:"
}

output "Raw_Data_Will_be_Stored_in" {
value = var.raw_data_bucket_name  
}

output "Cleaned_Data_Will_be_Stored_in" {
  value = var.cleaned_data_bucket_name
  
}
