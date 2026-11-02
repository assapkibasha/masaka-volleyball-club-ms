const axios = require("axios");
const https = require("https");
const qs = require("querystring");

const BULKSMS_URL = "https://bulksms.digitalservicescenter.rw/api/v2/sms/send";
const BATCH_SIZE = 20;
const MAX_CONCURRENT_BATCHES = 3;

// Reuse the TLS connection between batches instead of renegotiating it.
const httpsAgent = new https.Agent({ keepAlive: true });

async function sendBatch(recipients, message, credentials) {
  // BulkSMS API requires application/x-www-form-urlencoded (not JSON)
  const response = await axios.post(
    BULKSMS_URL,
    qs.stringify({ ...credentials, recipients: recipients.join(","), message }),
    {
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      timeout: 15000,
      httpsAgent,
    },
  );

  const data = response.data;

  if (data.status === "error") {
    throw new Error(data.message || "BulkSMS API returned an error.");
  }

  return Array.isArray(data.response) ? data.response : [];
}

/**
 * Send an SMS to one or more phone numbers via BulkSMS DigitalServicesCenter.
 *
 * Recipients are split into batches sent in parallel, so one slow or failed
 * batch does not fail the rest. A failed batch is reported per recipient with
 * status "failed" and an `error` message. Throws only if every batch failed.
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

  const credentials = { api_key: apiKey, username, password };
  if (sender) {
    credentials.sender = sender;
  }

  const batches = [];
  for (let i = 0; i < cleaned.length; i += BATCH_SIZE) {
    batches.push(cleaned.slice(i, i + BATCH_SIZE));
  }

  const outcomes = new Array(batches.length);
  let nextBatch = 0;

  async function runWorker() {
    while (nextBatch < batches.length) {
      const index = nextBatch++;
      try {
        outcomes[index] = { results: await sendBatch(batches[index], message, credentials) };
      } catch (error) {
        console.error(`[BulkSMS] Batch ${index + 1}/${batches.length} failed: ${error.message}`);
        outcomes[index] = { error };
      }
    }
  }

  const workerCount = Math.min(MAX_CONCURRENT_BATCHES, batches.length);
  await Promise.all(Array.from({ length: workerCount }, runWorker));

  if (outcomes.every((outcome) => outcome.error)) {
    throw outcomes[0].error;
  }

  const results = outcomes.flatMap((outcome, index) => (
    outcome.error
      ? batches[index].map((recipient) => ({ recipient, status: "failed", error: outcome.error.message }))
      : outcome.results
  ));
  const sent    = results.filter((r) => r.status === "sent").length;
  const failed  = results.filter((r) => r.status !== "sent").length;

  return { sent, failed, results };
}

module.exports = { sendSms, BATCH_SIZE };
