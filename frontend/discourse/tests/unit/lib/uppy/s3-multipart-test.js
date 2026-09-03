import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import UppyS3Multipart from "discourse/lib/uppy/s3-multipart";
import pretender from "discourse/tests/helpers/create-pretender";

module("Unit | Lib | Uppy | s3-multipart", function (hooks) {
  setupTest(hooks);

  test("includes audio metadata when completing an upload", async function (assert) {
    let requestBody;
    pretender.post("/uploads/complete-multipart.json", (request) => {
      requestBody = JSON.parse(request.requestBody);
      return [200, { "Content-Type": "application/json" }, {}];
    });

    const uppyInstance = {
      emit: sinon.stub(),
      use(_plugin, options) {
        this.options = options;
      },
    };
    const multipart = new UppyS3Multipart(this.owner, {
      errorHandler: sinon.stub(),
      uploadRootPath: "/uploads",
      uppyWrapper: { debug: { log: sinon.stub() } },
    });
    multipart.apply(uppyInstance);

    await uppyInstance.options.completeMultipartUpload(
      {
        id: "voice-file",
        meta: {
          audio_duration_ms: 2_000,
          audio_waveform: "encoded-waveform",
          audio_waveform_version: 1,
          unique_identifier: "voice-upload",
        },
      },
      { parts: [{ ETag: "etag", PartNumber: 1 }] }
    );

    assert.propContains(requestBody, {
      audio_duration_ms: 2_000,
      audio_waveform: "encoded-waveform",
      audio_waveform_version: 1,
      unique_identifier: "voice-upload",
    });
  });
});
