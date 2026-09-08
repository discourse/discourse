import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import UppyS3Multipart from "discourse/lib/uppy/s3-multipart";
import pretender, {
  middlewareRateLimit,
} from "discourse/tests/helpers/create-pretender";

const UPLOAD_ROOT_PATH = "/uploads";
const BATCH_PRESIGN_URL = "/uploads/batch-presign-multipart-parts.json";
const COMPLETE_URL = "/uploads/complete-multipart.json";
const RETRY_AFTER_SECONDS = 1;
const PART_NUMBER = 1;
const SIGNING_ATTEMPTS_BEFORE_RAISING = 4;

const OK = [200, { "Content-Type": "application/json" }, "{}"];
const SERVER_ERROR = [500, {}, ""];

function buildFile() {
  return { id: "file-1", name: "big.mp4", meta: { unique_identifier: "abc" } };
}

function awsS3Options(context, errorHandler) {
  const multipart = new UppyS3Multipart(getOwner(context), {
    uploadRootPath: UPLOAD_ROOT_PATH,
    uppyWrapper: { debug: { log: () => {} } },
    errorHandler,
  });

  let options;
  multipart.apply({
    use: (_plugin, opts) => (options = opts),
    emit: () => {},
  });

  return options;
}

module("Unit | Lib | uppy/s3-multipart", function (hooks) {
  setupTest(hooks);

  test("a signing failure reaches the configured error handler", async function (assert) {
    const errorHandler = sinon.spy();
    const { signPart } = awsS3Options(this, errorHandler);

    pretender.post(BATCH_PRESIGN_URL, () => SERVER_ERROR);

    const file = buildFile();
    await Promise.allSettled(
      Array.from({ length: SIGNING_ATTEMPTS_BEFORE_RAISING }, () =>
        signPart(file, { partNumber: PART_NUMBER })
      )
    );

    assert.true(
      errorHandler.calledOnce,
      "the error handler is called once, rather than throwing on a method that does not exist"
    );
    assert.strictEqual(
      errorHandler.firstCall.args[0],
      file,
      "the error handler receives the file"
    );
  });

  test("a rate limited complete-multipart is retried after Retry-After", async function (assert) {
    const { completeMultipartUpload } = awsS3Options(this, sinon.spy());

    const requests = [];
    pretender.post(COMPLETE_URL, () => {
      requests.push(Date.now());
      return requests.length === 1
        ? middlewareRateLimit(RETRY_AFTER_SECONDS)
        : OK;
    });

    await completeMultipartUpload(buildFile(), {
      parts: [{ PartNumber: PART_NUMBER, ETag: "etag" }],
    });

    assert.strictEqual(
      requests.length,
      2,
      "the completion is retried rather than discarding a fully uploaded file"
    );
    assert.true(
      requests[1] - requests[0] >= RETRY_AFTER_SECONDS * 1000,
      "the retry waits out the window the server advertised"
    );
  });
});
