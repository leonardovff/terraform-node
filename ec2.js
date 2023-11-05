const AWS = require('aws-sdk');

const ec2 = new AWS.EC2({ region: 'us-east-2' }); // Replace with your AWS region
const sqs = new AWS.SQS({ region: 'us-east-2' });

exports.handler = async (event) => {
  const currentTime = new Date();
  // Set the time zone offset to GMT-3
  currentTime.setUTCHours(currentTime.getUTCHours() - 3);
  console.log({ currentTime });

  const startHour = 12; // Replace with your start hour
  const stopHour = 21; // Replace with your stop hour
  const instanceId = 'i-0d1b4eb246ba78857'; // Replace with your EC2 instance ID
  const params = {
    InstanceIds: [instanceId],
  };
  
  let state = null;
  try {
    const data = await ec2.describeInstances(params).promise();
    const instance = data.Reservations[0].Instances[0];
    state = instance.State.Name;
  } catch (error) {
    console.error(`Error setting the EC2 instance ip in dynamic dnns: ${error}`);
  }
  const isRunning = ['running', 'pending'].includes(state);
  const currentHours = currentTime.getHours();
  const isToRun = currentHours >= startHour && currentHours < stopHour;
  if (!isRunning && isToRun) {
    // Start the EC2 instance
    console.log("started process of turn on ec2")
    const paramsSns = {
      MessageBody: JSON.stringify({ key: 'value' }),
      QueueUrl: 'https://sqs.us-east-2.amazonaws.com/162275354136/Ec2Queue', // Replace with your SQS queue URL
    };
    try {
      await ec2.startInstances(params).promise();
      await sqs.sendMessage(paramsSns).promise();
      console.log(`Started EC2 instance with ID: ${instanceId}`);
    } catch (error) {
      console.error(`Error starting EC2 instance: ${error}`);
    }
    return 'Function execution completed';
  }

  if(isRunning && !isToRun) {
    // Stop the EC2 instance
    console.log("started process of turn off ec2")
    try {
      await ec2.stopInstances(params).promise();
      console.log(`Stopped EC2 instance with ID: ${instanceId}`);
    } catch (error) {
      console.error(`Error stopping EC2 instance: ${error}`);
    }
  }

  return 'Function execution completed';
};