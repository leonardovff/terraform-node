const AWS = require('aws-sdk');

const ec2 = new AWS.EC2({ region: 'us-east-2' }); // Replace with your AWS region

exports.handler = async (event) => {
  const currentTime = new Date();

  // Set the time zone offset to GMT-3
  currentTime.setUTCHours(currentTime.getUTCHours() - 3);

  const startHour = 12; // Replace with your start hour
  const stopHour = 21; // Replace with your stop hour
  const instanceId = 'i-0d1b4eb246ba78857'; // Replace with your EC2 instance ID
  const params = {
    InstanceIds: [instanceId],
  };
  console.log(currentTime);


  if (currentTime.getHours() >= startHour && currentTime.getHours() < stopHour) {
    // Start the EC2 instance
    const instanceId = 'i-0d1b4eb246ba78857'; // Replace with your EC2 instance ID
    const params = {
      InstanceIds: [instanceId],
    };

    try {
      await ec2.startInstances(params).promise();
      console.log(`Started EC2 instance with ID: ${instanceId}`);
    } catch (error) {
      console.error(`Error starting EC2 instance: ${error}`);
    }
  } else {
    // Stop the EC2 instance
    try {
      await ec2.stopInstances(params).promise();
      console.log(`Stopped EC2 instance with ID: ${instanceId}`);
    } catch (error) {
      console.error(`Error stopping EC2 instance: ${error}`);
    }
  }

  return 'Function execution completed';
};