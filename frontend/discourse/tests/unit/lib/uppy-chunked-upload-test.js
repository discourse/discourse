import { waitUntil } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import UppyChunkedUpload from "discourse/lib/uppy-chunked-upload";
import pretender, {
  middlewareRateLimit,
} from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";

const UPLOAD_URL = "/admin/backups/upload";
const RETRY_AFTER_SECONDS = 1;
const RATE_LIMITED_CHUNK = 1;
const FILE_CONTENT = "abcdef";
const MANUAL_PRETENDER_RESOLUTION = true;
const OK = [200, {}, "{}"];
const SERVICE_UNAVAILABLE = [503, {}, ""];

function startUpload(respondWith, { options, timing } = {}) {
  const requests = [];

  pretender.post(
    UPLOAD_URL,
    (request) => {
      const chunk = parseInt(
        request.requestBody.get("resumableChunkNumber"),
        10
      );
      requests.push({ chunk, at: Date.now() });

      return respondWith(chunk, requests);
    },
    timing
  );

  const outcome = { errors: [], successes: 0 };
  const data = createFile("backup.tar.gz", "application/gzip", FILE_CONTENT);

  const upload = new UppyChunkedUpload(
    { data, size: data.size },
    {
      url: UPLOAD_URL,
      method: "POST",
      getChunkSize: null,
      limit: 5,
      retryDelays: [0, 0, 0, 0],
      onSuccess: () => outcome.successes++,
      onError: (err) => outcome.errors.push(err),
      ...options,
    }
  );
  upload.start();

  return { upload, requests, outcome };
}

function attemptsFor(requests, chunk) {
  return requests.filter((request) => request.chunk === chunk);
}

module("Unit | Lib | uppy-chunked-upload", function (hooks) {
  setupTest(hooks);

  test("a rate limited chunk is retried after the advertised Retry-After", async function (assert) {
    const { requests, outcome } = startUpload(
      (chunk, sent) =>
        chunk === RATE_LIMITED_CHUNK && attemptsFor(sent, chunk).length === 1
          ? middlewareRateLimit(RETRY_AFTER_SECONDS)
          : OK,
      { options: { getChunkSize: () => 1 } }
    );

    await waitUntil(() => outcome.successes > 0, {
      timeout: (RETRY_AFTER_SECONDS + 4) * 1000,
    });

    const attempts = attemptsFor(requests, RATE_LIMITED_CHUNK);

    assert.strictEqual(
      attempts.length,
      2,
      "the rate limited chunk is retried exactly once, with no concurrent duplicate retry"
    );
    assert.true(
      attempts[1].at - attempts[0].at >= RETRY_AFTER_SECONDS * 1000,
      "the retry waits for Retry-After rather than the fixed retry delay"
    );
    assert.strictEqual(
      requests.length,
      FILE_CONTENT.length + 1,
      "every other chunk is uploaded exactly once"
    );
    assert.strictEqual(outcome.errors.length, 0, "no error is surfaced");
  });

  test("a 503 is retried for every retry delay", async function (assert) {
    const { requests, outcome } = startUpload((chunk, sent) =>
      sent.length > 4 ? OK : SERVICE_UNAVAILABLE
    );

    await waitUntil(() => outcome.successes > 0);

    assert.strictEqual(
      requests.length,
      5,
      "the chunk is retried once per retry delay before succeeding"
    );
    assert.strictEqual(outcome.errors.length, 0, "no error is surfaced");
  });

  test("a supplied getChunkSize is used to split the file", async function (assert) {
    const { requests, outcome } = startUpload(() => OK, {
      options: { getChunkSize: () => 2 },
    });

    await waitUntil(() => outcome.successes > 0);

    assert.deepEqual(
      requests.map((request) => request.chunk),
      [1, 2, 3],
      "the file is split into 2 byte chunks"
    );
  });

  test("aborting cancels the in-flight request", async function (assert) {
    const abort = sinon.spy(XMLHttpRequest.prototype, "abort");
    const { upload, requests } = startUpload(() => OK, {
      timing: MANUAL_PRETENDER_RESOLUTION,
    });

    await waitUntil(() => requests.length > 0);

    assert.strictEqual(
      abort.callCount,
      0,
      "nothing is aborted while the upload is running"
    );

    upload.abort({ really: true });

    assert.strictEqual(abort.callCount, 1, "the in-flight request is aborted");
  });
});
