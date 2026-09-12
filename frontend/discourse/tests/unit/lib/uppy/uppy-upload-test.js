import { getOwner } from "@ember/owner";
import { waitUntil } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { dialog } from "discourse/lib/uploads";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import pretender from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";

const UPLOAD_URL = "/uploads.json";
const REJECTED_FILE = "rejected.png";
const SIBLING_FILE = "sibling.png";
const JSON_HEADERS = { "Content-Type": "application/json" };

const UNPROCESSABLE = [
  422,
  JSON_HEADERS,
  JSON.stringify({ message: "upload failed" }),
];

function uploadResponse(fileName) {
  return [
    200,
    JSON_HEADERS,
    JSON.stringify({
      id: 1,
      url: `/uploads/${fileName}`,
      short_url: `upload://${fileName}`,
      original_filename: fileName,
    }),
  ];
}

module("Unit | Lib | uppy/uppy-upload", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.fileInput = document.createElement("input");
    this.fileInput.type = "file";
    this.fileInput.multiple = true;
    document.body.appendChild(this.fileInput);
  });

  hooks.afterEach(function () {
    this.fileInput.remove();
    sinon.restore();
  });

  test("a rejected upload does not cancel the rest of the batch", async function (assert) {
    const alert = sinon.stub(dialog, "alert");
    const completed = [];

    let rejectionDelivered;
    const siblingReleasedByRejection = new Promise(
      (resolve) => (rejectionDelivered = resolve)
    );

    pretender.post(UPLOAD_URL, async (request) => {
      const fileName = request.requestBody.get("file").name;

      if (fileName === REJECTED_FILE) {
        return UNPROCESSABLE;
      }

      await siblingReleasedByRejection;
      return uploadResponse(fileName);
    });

    const upload = new UppyUpload(getOwner(this), {
      id: "uppy-upload-test",
      type: "composer",
      uploadDone: ({ file_name }) => completed.push(file_name),
    });

    upload.setup(this.fileInput);
    upload.uppyWrapper.uppyInstance.on("upload-error", () =>
      rejectionDelivered()
    );

    await upload.addFiles([
      createFile(REJECTED_FILE),
      createFile(SIBLING_FILE),
    ]);

    await waitUntil(() => !upload.uploading && completed.length > 0, {
      timeout: 5000,
    });

    assert.deepEqual(
      completed,
      [SIBLING_FILE],
      "the sibling upload finishes instead of being aborted"
    );
    assert.true(
      alert.calledOnceWith("upload failed"),
      "the rejection is reported once, with the server's own message"
    );

    upload.teardown();
  });

  test("a batch drained by a cancel still reports the failure", async function (assert) {
    const alert = sinon.stub(dialog, "alert");

    pretender.post(UPLOAD_URL, async (request) => {
      const fileName = request.requestBody.get("file").name;

      if (fileName === REJECTED_FILE) {
        return UNPROCESSABLE;
      }

      await new Promise(() => {});
    });

    const upload = new UppyUpload(getOwner(this), {
      id: "uppy-upload-cancel-test",
      type: "composer",
      uploadDone: () => {},
    });

    upload.setup(this.fileInput);
    upload.uppyWrapper.uppyInstance.on("upload-error", () => {
      const sibling = upload.inProgressUploads.find(
        (inProgress) => inProgress.fileName === SIBLING_FILE
      );
      upload.cancelSingleUpload({ fileId: sibling.id });
    });

    await upload.addFiles([
      createFile(REJECTED_FILE),
      createFile(SIBLING_FILE),
    ]);

    await waitUntil(() => !upload.uploading, { timeout: 5000 });

    assert.true(
      alert.calledOnceWith("upload failed"),
      "the buffered failure is reported once the cancel drains the batch"
    );

    upload.teardown();
  });
});
