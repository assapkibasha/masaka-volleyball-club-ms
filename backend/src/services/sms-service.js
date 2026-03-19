const axios = require("axios");
const qs = require("querystring");

const BULKSMS_URL = "https://bulksms.digitalservicescenter.rw/api/v2/sms/send";

/**
 * Send an SMS to one or more phone numbers via BulkSMS DigitalServicesCenter.
 *
 * @param {string[]} phones   - Array of phone numbers (e.g. ["250782589800"])
 * @param {string}   message  - The message body to send
 * @returns {Promise<{ sent: number, failed: number, results: object[] }>}
 */
async function sendSms(phones, message) {
  if (!phones || phones.length === 0) {
    throw new Error("No phone numbers provided.");
  }

  const apiKey   = process.env.BULKSMS_API_KEY;
  const username = process.env.BULKSMS_USERNAME;
  const password = process.env.BULKSMS_PASSWORD;
  const sender   = process.env.BULKSMS_SENDER_ID || undefined;

  if (!apiKey || !username || !password) {
    throw new Error("BulkSMS credentials are not configured in environment variables.");
  }

  // Clean phone numbers: strip spaces and leading '+'
  const cleaned = phones
    .filter(Boolean)
    .map((p) => p.replace(/\s+/g, "").replace(/^\+/, ""));

  const payload = {
    api_key: apiKey,
    username,
    password,
    recipients: cleaned.join(","),
    message,
  };

  if (sender) {
    payload.sender = sender;
  }

  // BulkSMS API requires application/x-www-form-urlencoded (not JSON)
  const response = await axios.post(BULKSMS_URL, qs.stringify(payload), {
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    timeout: 15000,
  });

  const data = response.data;
  console.log("[BulkSMS] Raw response:", JSON.stringify(data));

  if (data.status === "error") {
    throw new Error(data.message || "BulkSMS API returned an error.");
  }

  const results = Array.isArray(data.response) ? data.response : [];
  const sent    = results.filter((r) => r.status === "sent").length;
  const failed  = results.filter((r) => r.status !== "sent").length;

  return { sent, failed, results, raw: data };
}

module.exports = { sendSms };
