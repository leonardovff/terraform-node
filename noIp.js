const axios = require('axios');
const AWS = require('aws-sdk');

const ec2 = new AWS.EC2({ region: 'us-east-2' });
const instanceId = 'i-0d1b4eb246ba78857';
const params = {
    InstanceIds: [instanceId],
};

exports.handler = async (event, context) => {
    let ip = null;
    try {
        const data = await ec2.describeInstances(params).promise();
        const instance = data.Reservations[0].Instances[0];
        ip = instance.PublicIpAddress;
    } catch (error) {
        console.error(`Error setting the EC2 instance ip in dynamic dnns: ${error}`);
    }

    if(!ip){
        return 'Without ip associated'
    }

    // Your No-IP username and password
    const username = process.env.USERNAME;
    const password = process.env.PASSWORD;
    
    // Your No-IP hostname
    const hostname = "security-ifal.ddns.net";
    
    // API endpoint for No-IP dynamic DNS update
    const api_url = `https://dynupdate.no-ip.com/nic/update?hostname=${hostname}&myip=${ip}`;
    
    // Set up authentication headers
    const authHeader = Buffer.from(`${username}:${password}`).toString('base64');
    
    try {
        const response = await axios.get(api_url, {
            headers: {
                'Authorization': `Basic ${authHeader}`,
            },
        });
        
        if (response.status === 200) {
            console.log('foi')
            return {
                statusCode: 200,
                body: 'No-IP update successful!',
            };
        } else {
            return {
                statusCode: response.status,
                body: `Failed to update No-IP: ${response.data}`,
            };
        }
    } catch (error) {
        return {
            statusCode: 500,
            body: `Error: ${error.message}`,
        };
    }
};
