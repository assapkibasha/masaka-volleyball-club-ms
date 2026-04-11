const axios = require("axios");
const qs = require("querystring");

const payload = {
  api_key: "f44d0979164ac0fe82f7b4293129991ccfa884ea8ab3f1dbb99c2b7bd2e7a048",
  username: "masakavolleyball804",
  password: "Tgk3I4VM4",
  sender: "VerifyNow",
  recipients: "250794008384",
  message: "Test from MVCS system. Please ignore.",
};

console.log("Sending to BulkSMS API...");
console.log("Payload:", JSON.stringify(payload, null, 2));

axios.post(
  "https://bulksms.digitalservicescenter.rw/api/v2/sms/send",
  qs.stringify(payload),
  { headers: { "Content-Type": "application/x-www-form-urlencoded" }, timeout: 15000 }
)
.then((res) => {
  console.log("\n✅ HTTP Status:", res.status);
  console.log("Response:", JSON.stringify(res.data, null, 2));
})
.catch((err) => {
  if (err.response) {
    console.error("\n❌ HTTP Error:", err.response.status);
    console.error("Response:", JSON.stringify(err.response.data, null, 2));
  } else {
    console.error("\n❌ Network Error:", err.message);
  }
});
