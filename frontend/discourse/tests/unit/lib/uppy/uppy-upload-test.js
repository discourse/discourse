import { getOwner } from "@ember/owner";
import { settled, waitUntil } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import loadUppy, { resetUppyForTesting } from "discourse/lib/load-uppy";
import { dialog } from "discourse/lib/uploads";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import pretender from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

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

  hooks.beforeEach(async function () {
    await loadUppy();
  });

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

  function buildUpload(context, config = {}) {
    return new UppyUpload(getOwner(context), {
      id: "uppy-upload-test",
      type: "composer",
      autoStartUploads: false,
      uploadDone: () => {},
      ...config,
    });
  }

  module("while the runtime loads", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      resetUppyForTesting();
    });

    nestedHooks.afterEach(function () {
      resetUppyForTesting();
    });

    test("setup binds once the runtime loads", async function (assert) {
      const upload = buildUpload(this);

      upload.setup(this.fileInput);
      assert.strictEqual(
        upload.uppyWrapper.uppyInstance,
        undefined,
        "the instance waits for the runtime"
      );

      await settled();
      assert.notStrictEqual(
        upload.uppyWrapper.uppyInstance,
        undefined,
        "the instance exists once the runtime loads"
      );

      upload.teardown();
    });

    test("files added while loading reach the uploader", async function (assert) {
      const upload = buildUpload(this);

      upload.setup(this.fileInput);
      await upload.addFiles([createFile(SIBLING_FILE)], { pasted: true });

      assert.deepEqual(
        upload.uppyWrapper.uppyInstance.getFiles().map((file) => file.name),
        [SIBLING_FILE],
        "the early file is added once the runtime loads"
      );

      upload.teardown();
    });

    test("teardown while loading cancels the pending setup", async function (assert) {
      const upload = buildUpload(this);

      upload.setup(this.fileInput);
      upload.teardown();
      await settled();

      assert.strictEqual(
        upload.uppyWrapper.uppyInstance,
        undefined,
        "no instance is created after teardown"
      );
    });

    test("files queued for a replaced setup are dropped", async function (assert) {
      const upload = buildUpload(this);

      upload.setup(this.fileInput);
      const adding = upload.addFiles([createFile(SIBLING_FILE)]);
      upload.teardown();
      upload.setup(this.fileInput);
      await adding;
      await settled();

      assert.deepEqual(
        upload.uppyWrapper.uppyInstance.getFiles(),
        [],
        "the replacement uploader does not receive the old files"
      );

      upload.teardown();
    });

    test("files dropped while loading reach the uploader", async function (assert) {
      const target = document.createElement("div");
      document.body.appendChild(target);
      const upload = buildUpload(this, { uploadDropTargetOptions: { target } });

      upload.setup(this.fileInput);
      const dataTransfer = new DataTransfer();
      dataTransfer.items.add(createFile(SIBLING_FILE));
      const drop = new DragEvent("drop", {
        bubbles: true,
        cancelable: true,
        dataTransfer,
      });
      target.dispatchEvent(drop);

      assert.true(drop.defaultPrevented, "the browser does not open the file");

      await waitUntil(
        () => upload.uppyWrapper.uppyInstance?.getFiles().length > 0
      );
      assert.deepEqual(
        upload.uppyWrapper.uppyInstance.getFiles().map((file) => file.name),
        [SIBLING_FILE],
        "the dropped file is added once the runtime loads"
      );

      upload.teardown();
      target.remove();
    });

    test("a failed load is reported once per page", async function (assert) {
      resetUppyForTesting({
        importer: () => Promise.reject(new Error("chunk failed")),
      });
      const alert = sinon.stub(
        getOwner(this).lookup("service:dialog"),
        "alert"
      );
      const first = buildUpload(this, { id: "first-upload" });
      const second = buildUpload(this, { id: "second-upload" });

      first.setup(this.fileInput);
      second.setup(this.fileInput);
      await first.addFiles([createFile(SIBLING_FILE)]);
      await second.addFiles([createFile(SIBLING_FILE)]);

      assert.true(alert.calledOnce, "one notice covers every uploader");
      assert.true(
        alert.calledWith(i18n("upload_selector.runtime_load_failed")),
        "the notice explains how to recover"
      );
    });
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

  test("a successful upload is not reported as cancelled", async function (assert) {
    const completed = [];
    const cancelled = [];

    pretender.post(UPLOAD_URL, (request) =>
      uploadResponse(request.requestBody.get("file").name)
    );

    const upload = new UppyUpload(getOwner(this), {
      id: "uppy-upload-success-test",
      type: "composer",
      uploadDone: ({ file_name }) => completed.push(file_name),
    });

    upload.setup(this.fileInput);
    getOwner(this)
      .lookup("service:app-events")
      .on("upload-mixin:uppy-upload-success-test:upload-cancelled", (fileId) =>
        cancelled.push(fileId)
      );
    getOwner(this)
      .lookup("service:app-events")
      .on("upload-mixin:uppy-upload-success-test:uploads-cancelled", () =>
        cancelled.push("uploads-cancelled")
      );

    await upload.addFiles([createFile(SIBLING_FILE)]);

    await waitUntil(() => !upload.uploading && completed.length > 0, {
      timeout: 5000,
    });

    assert.deepEqual(completed, [SIBLING_FILE], "the upload finishes");
    assert.deepEqual(
      cancelled,
      [],
      "the finished upload is not reported as cancelled"
    );

    upload.teardown();
  });

  test("explicit single-file cancellation is reported", async function (assert) {
    const cancellations = [];
    const upload = new UppyUpload(getOwner(this), {
      id: "uppy-upload-cancel-single-test",
      type: "composer",
      autoStartUploads: false,
      uploadDone: () => {},
    });

    upload.setup(this.fileInput);
    getOwner(this)
      .lookup("service:app-events")
      .on(
        "upload-mixin:uppy-upload-cancel-single-test:upload-cancelled",
        (fileId) => cancellations.push(fileId)
      );

    await upload.addFiles([createFile(SIBLING_FILE)]);
    const fileId = upload.uppyWrapper.uppyInstance.getFiles()[0].id;
    upload.cancelSingleUpload({ fileId });

    assert.deepEqual(
      cancellations,
      [fileId],
      "explicit cancellation reports the removed file once"
    );
    assert.deepEqual(
      upload.uppyWrapper.uppyInstance.getFiles(),
      [],
      "the cancelled file is removed"
    );

    upload.teardown();
  });

  test("explicit cancel all is reported as cancelled", async function (assert) {
    const cancellations = [];
    const upload = new UppyUpload(getOwner(this), {
      id: "uppy-upload-cancel-all-test",
      type: "composer",
      autoStartUploads: false,
      uploadDone: () => {},
    });

    upload.setup(this.fileInput);
    getOwner(this)
      .lookup("service:app-events")
      .on("upload-mixin:uppy-upload-cancel-all-test:uploads-cancelled", () =>
        cancellations.push("uploads-cancelled")
      );

    await upload.addFiles([createFile(SIBLING_FILE)]);
    upload.cancelAllUploads();

    assert.deepEqual(
      cancellations,
      ["uploads-cancelled"],
      "explicit cancel all reports one cancellation"
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
