const assert = require("node:assert/strict");
const qs = require("node:querystring");
const { afterEach, beforeEach, test } = require("node:test");

const axios = require("axios");

const { sendSms, BATCH_SIZE } = require("../src/services/sms-service");

const originalPost = axios.post;
const originalEnv = { ...process.env };

function phones(count) {
  return Array.from({ length: count }, (_, index) => `25078${String(index).padStart(7, "0")}`);
}

function sentResponse(body) {
  const recipients = qs.parse(body).recipients.split(",");
  return {
    data: {
      status: "success",
      response: recipients.map((recipient, index) => ({
        recipient,
        status: "sent",
        messageid: `id-${recipient}-${index}`,
      })),
    },
  };
}

beforeEach(() => {
  process.env.BULKSMS_API_KEY = "test-key";
  process.env.BULKSMS_USERNAME = "test-user";
  process.env.BULKSMS_PASSWORD = "test-password";
});

afterEach(() => {
  axios.post = originalPost;
  process.env = { ...originalEnv };
});

test("splits recipients into batches and returns every result", async () => {
  const batchSizes = [];
  axios.post = async (_url, body) => {
    batchSizes.push(qs.parse(body).recipients.split(",").length);
    return sentResponse(body);
  };

  const result = await sendSms(phones(BATCH_SIZE * 2 + 5), "Hello");

  assert.deepEqual(batchSizes.sort((a, b) => b - a), [BATCH_SIZE, BATCH_SIZE, 5]);
  assert.equal(result.sent, BATCH_SIZE * 2 + 5);
  assert.equal(result.failed, 0);
  assert.equal(new Set(result.results.map((r) => r.recipient)).size, BATCH_SIZE * 2 + 5);
});

test("sends batches in parallel, capped at three at a time", async () => {
  let active = 0;
  let peak = 0;
  axios.post = async (_url, body) => {
    active += 1;
    peak = Math.max(peak, active);
    await new Promise((resolve) => setTimeout(resolve, 5));
    active -= 1;
    return sentResponse(body);
  };

  await sendSms(phones(BATCH_SIZE * 7), "Hello");

  assert.equal(peak, 3);
});

test("reports only the recipients of a failed batch as failed", async () => {
  let call = 0;
  axios.post = async (_url, body) => {
    call += 1;
    if (call === 1) {
      throw new Error("timeout of 15000ms exceeded");
    }
    return sentResponse(body);
  };

  const result = await sendSms(phones(BATCH_SIZE + 3), "Hello");

  assert.equal(result.failed, BATCH_SIZE);
  assert.equal(result.sent, 3);
  const failed = result.results.find((r) => r.status === "failed");
  assert.equal(failed.error, "timeout of 15000ms exceeded");
});

test("throws when every batch fails so callers can report the cause", async () => {
  axios.post = async () => ({ data: { status: "error", message: "Invalid API key or credentials" } });

  await assert.rejects(sendSms(phones(BATCH_SIZE + 1), "Hello"), /Invalid API key or credentials/);
});

test("never logs credentials", async () => {
  const logged = [];
  const originalLog = console.log;
  console.log = (...args) => logged.push(args.join(" "));
  axios.post = async (_url, body) => sentResponse(body);

  try {
    await sendSms(phones(1), "Hello");
  } finally {
    console.log = originalLog;
  }

  assert.equal(logged.join("\n").includes("test-password"), false);
  assert.equal(logged.join("\n").includes("test-key"), false);
});
