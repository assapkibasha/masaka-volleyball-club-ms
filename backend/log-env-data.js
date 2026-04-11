require('dotenv').config();
const qs = require('querystring');

const apiKey = process.env.BULKSMS_API_KEY || '';
const username = process.env.BULKSMS_USERNAME || '';
const password = process.env.BULKSMS_PASSWORD || '';
const sender = process.env.BULKSMS_SENDER_ID || '';

const payload = {
  api_key: apiKey,
  username: username,
  password: password,
  recipients: '0794008384',
  message: 'Test message for logging payload'
};

if (sender) {
  payload.sender = sender;
}

console.log('========== LOADED ENVIRONMENT VARIABLES (RETRIEVALS) ==========');
console.log('BULKSMS_URL       :', 'https://bulksms.digitalservicescenter.rw/api/v2/sms/send');
console.log('BULKSMS_API_KEY   :', apiKey ? `[${apiKey.length} characters] ${apiKey.substring(0,8)}...` : 'UNDEFINED or EMPTY');
console.log('BULKSMS_USERNAME  :', username ? `[${username.length} characters] ${username}` : 'UNDEFINED or EMPTY');
console.log('BULKSMS_PASSWORD  :', password ? `[${password.length} characters] ${password}` : 'UNDEFINED or EMPTY');
console.log('BULKSMS_SENDER_ID :', sender ? `[${sender.length} characters] ${sender}` : 'UNDEFINED or EMPTY');

console.log('\n========== THE EXACT RAW PAYLOAD OBJECT WE ARE USING ==========');
console.log(payload);

console.log('\n========== THE URL-ENCODED STRING SENT TO THE API ==========');
console.log(qs.stringify(payload));
console.log('===============================================================');
