variable "region" {
  type = string
  default = "us-east-2"
}

variable "raw_data_bucket_name" {
    type = string
  default = "raw-weather-data-bucket"
}
variable "cleaned_data_bucket_name" {
    type = string
  default = "cleaned-weather-data-bucket"
}

variable "sns-topic-name" {
  type = string
  default = "sns-email-alerrt-notification"
}

variable "sns-email" {
  type = string
  default = "skattegu@asu.edu"
}

variable "lambda_role_name" {
  type = string
  default = "lambda_weather_role"
}

variable "Lambda_policy_name" {
  type = string
  default = "lambda_weather_policy"
}

variable "lambda_function_name" {
  type = string
  default = "lambda_weather_function"
}