const axios = require('axios');
const fs = require('fs');
require('dotenv').config();

async function testApi() {
  const url = 'https://bulksms.digitalservicescenter.rw/api/v2/sms/send';
  const apiKey = process.env.BULKSMS_API_KEY;
  const username = process.env.BULKSMS_USERNAME;
  const password = process.env.BULKSMS_PASSWORD;
  
  const payloadJson = {
    api_key: apiKey,
    username: username,
    password: password,
    sender: 'VerifyNow',
    recipients: '0794008384',
    message: 'Test message'
  };

  try {
    const res = await axios.post(url, payloadJson, {
      headers: { 'Content-Type': 'application/json' },
      timeout: 10000
    });
    console.log('\n--- APPLICATION/JSON RESPONSE ---');
    console.log(res.data);
  } catch (err) {
    console.log('\n--- APPLICATION/JSON ERROR ---');
    console.error(err.response ? err.response.data : err.message);
  }

  try {
    const qs = require('querystring');
    const res = await axios.post(url, qs.stringify(payloadJson), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      timeout: 10000
    });
    console.log('\n--- X-WWW-FORM-URLENCODED RESPONSE ---');
    console.log(res.data);
  } catch (err) {
    console.log('\n--- X-WWW-FORM-URLENCODED ERROR ---');
    console.error(err.response ? err.response.data : err.message);
  }
}

testApi();
