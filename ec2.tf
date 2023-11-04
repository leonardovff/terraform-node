provider "aws" {
  region = "us-east-2" # Change this to your desired AWS region
}

resource "aws_lambda_function" "ec2_controller" {
  function_name = "EC2Controller"
  handler      = "ec2.handler"
  runtime      = "nodejs14.x"
  source_code_hash = filebase64sha256("./code.zip")
  role         = aws_iam_role.lambda_exec_role.arn
  filename     = "./code.zip" # Replace with the path to your Lambda code
}

data "aws_iam_policy_document" "cloudwatch_logs" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cloudwatch_logs" {
  name        = "CloudWatchLogsPolicy"
  description = "Allows writing to CloudWatch Logs"
  policy      = data.aws_iam_policy_document.cloudwatch_logs.json
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_logs" {
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
  role       = aws_iam_role.lambda_exec_role.name
}

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
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec_role_attachment" {
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
  role       = aws_iam_role.lambda_exec_role.name
}

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