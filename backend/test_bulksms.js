const axios = require("axios");
const qs = require("querystring");

const creds = {
  api_key: "f44d0979164ac0fe82f7b4293129991ccfa884ea8ab3f1dbb99c2b7bd2e7a048",
  username: "masakavolleyball804",
  password: "Tgk3I4VM4",
  sender: "VerifyNow",
  recipients: "250794008384",
  message: "Test from MVCS. Please ignore.",
};

const URL = "https://bulksms.digitalservicescenter.rw/api/v2/sms/send";

async function test(label, fn) {
  console.log(`\n--- ${label} ---`);
  try {
    const res = await fn();
    console.log("HTTP:", res.status);
    console.log("Body:", JSON.stringify(res.data, null, 2));
  } catch (e) {
    if (e.response) {
      console.error("HTTP Error:", e.response.status);
      console.error("Body:", JSON.stringify(e.response.data, null, 2));
    } else {
      console.error("Network error:", e.message);
    }
  }
}

(async () => {
  // Try 1: JSON body (as shown in their Node.js example)
  await test("application/json", () =>
    axios.post(URL, creds, { timeout: 15000 })
  );

  // Try 2: form-urlencoded (as shown in their PHP/cURL example)
  await test("application/x-www-form-urlencoded", () =>
    axios.post(URL, qs.stringify(creds), {
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      timeout: 15000,
    })
  );

  // Try 3: form-urlencoded WITHOUT sender field
  const { sender, ...withoutSender } = creds;
  await test("no sender field (form-urlencoded)", () =>
    axios.post(URL, qs.stringify(withoutSender), {
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      timeout: 15000,
    })
  );
})();
