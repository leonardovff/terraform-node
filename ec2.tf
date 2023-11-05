provider "aws" {
  region = "us-east-2" # Change this to your desired AWS region
}

resource "aws_sqs_queue" "ec2_queue" {
  name = "Ec2Queue"
  visibility_timeout_seconds = 60  # Set the visibility timeout to 60 seconds
}

# Create an IAM policy document for CloudWatch Logs permissions (same as before)
data "aws_iam_policy_document" "cloudwatch_logs" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
}

# Create an IAM policy for CloudWatch Logs permissions (same as before)
resource "aws_iam_policy" "cloudwatch_logs" {
  name        = "CloudWatchLogsPolicy"
  description = "Allows writing to CloudWatch Logs"
  policy      = data.aws_iam_policy_document.cloudwatch_logs.json
}

# Attach the CloudWatch Logs policy to the Lambda execution role (same as before)
resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_logs" {
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
  role       = aws_iam_role.lambda_exec_role.name
}

# Define the Lambda execution role (same as before)
resource "aws_iam_role" "lambda_exec_role" {
  name = "LambdaEC2ControllerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Define the IAM policy for Lambda execution permissions (same as before)
resource "aws_iam_policy" "lambda_exec_policy" {
  name = "LambdaEC2ControllerPolicy"

  description = "Policy for Lambda to control EC2 instances"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstances"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:SendMessage",
        ],
        Effect = "Allow",
        Resource = aws_sqs_queue.ec2_queue.arn,  # Corrected resource attribute
      },
    ]
  })
}

# Attach the IAM policy for Lambda execution permissions to the role (same as before)
resource "aws_iam_role_policy_attachment" "lambda_exec_role_attachment" {
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
  role       = aws_iam_role.lambda_exec_role.name
}

# Define the first Lambda function (with CloudWatch trigger)
resource "aws_lambda_function" "ec2_controller" {
  function_name = "EC2Controller"
  handler      = "ec2.handler"
  runtime      = "nodejs14.x"
  source_code_hash = filebase64sha256("./dist/code.zip")
  role         = aws_iam_role.lambda_exec_role.arn
  filename     = "./dist/code.zip" # Replace with the path to your Lambda code
}

# Create permissions for CloudWatch trigger on the first Lambda function
resource "aws_lambda_permission" "cloudwatch_trigger" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_controller.function_name
  principal     = "events.amazonaws.com"

  source_arn = aws_cloudwatch_event_rule.schedule.arn
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name        = "EC2ControllerSchedule"
  description = "Schedule for EC2 Controller Lambda"
  schedule_expression = "rate(60 minutes)" # Adjust the schedule as needed
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule = aws_cloudwatch_event_rule.schedule.name
  target_id = "EC2ControllerLambdaTarget"
  arn = aws_lambda_function.ec2_controller.arn
}

variable "no_ip_username" {
  type        = string
  description = "AMI ID for the EC2 instance"
  default     = ""
}


variable "no_ip_password" {
  type        = string
  description = "AMI ID for the EC2 instance"
  default     = ""
}


# Define the second Lambda function (without CloudWatch trigger)
resource "aws_lambda_function" "ec2_controller_ip" {
  function_name = "EC2ControllerIp"
  handler      = "noIp.handler"
  runtime      = "nodejs14.x"
  source_code_hash = filebase64sha256("./dist/code.zip")
  role         = aws_iam_role.lambda_exec_role.arn
  filename     = "./dist/code.zip" # Replace with the path to your Lambda code
  environment {
    variables = {
      PASSWORD =  var.no_ip_password,
      USERNAME = var.no_ip_username,
    }
  }
}

# Configure the sender Lambda function to send messages to the SQS queue
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn   = aws_sqs_queue.ec2_queue.arn
  function_name      = aws_lambda_function.ec2_controller_ip.function_name
  batch_size         = 1
  enabled            = true
  # starting_position  = "LATEST"
  maximum_batching_window_in_seconds = 60
}



