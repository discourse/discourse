import { destroy } from "@ember/destroyable";
import { getOwner, setOwner } from "@ember/owner";
import { run } from "@ember/runloop";
import { triggerEvent, waitUntil } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
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

    this.parent = {};
    setOwner(this.parent, getOwner(this));
  });

  hooks.afterEach(function () {
    run(() => destroy(this.parent));
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

    const upload = new UppyUpload(this.parent, {
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
  });

  test("a successful upload is not reported as cancelled", async function (assert) {
    const completed = [];
    const cancelled = [];

    pretender.post(UPLOAD_URL, (request) =>
      uploadResponse(request.requestBody.get("file").name)
    );

    const upload = new UppyUpload(this.parent, {
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
  });

  test("explicit single-file cancellation is reported", async function (assert) {
    const cancellations = [];
    const upload = new UppyUpload(this.parent, {
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
  });

  test("explicit cancel all is reported as cancelled", async function (assert) {
    const cancellations = [];
    const upload = new UppyUpload(this.parent, {
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

    const upload = new UppyUpload(this.parent, {
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
  });

  test("teardown destroys the Uppy instance", function (assert) {
    const upload = new UppyUpload(this.parent, {
      id: "uppy-upload-teardown-test",
      type: "composer",
      uploadDone: () => {},
    });

    upload.setup(this.fileInput);
    const uppyDestroy = sinon.spy(upload.uppyWrapper.uppyInstance, "destroy");
    upload.teardown();

    assert.true(uppyDestroy.calledOnce, "destroys the instance");
  });

  test("destroying the parent tears down", function (assert) {
    const upload = new UppyUpload(this.parent, {
      id: "uppy-upload-parent-test",
      type: "composer",
      uploadDone: () => {},
    });

    upload.setup(this.fileInput);
    const uppyDestroy = sinon.spy(upload.uppyWrapper.uppyInstance, "destroy");
    run(() => destroy(this.parent));

    assert.true(uppyDestroy.calledOnce, "destroys the Uppy instance");
  });

  test("still accepts an owner", function (assert) {
    const owner = getOwner(this);
    const upload = withSilencedDeprecations(
      "discourse.uppy-upload-owner",
      () =>
        new UppyUpload(owner, {
          id: "uppy-upload-owner-test",
          type: "composer",
          uploadDone: () => {},
        })
    );

    upload.setup(this.fileInput);

    assert.strictEqual(getOwner(upload), owner, "uses it as the owner");
  });

  test("attachFileInput rebinds an input without interrupting an upload", async function (assert) {
    let requested = false;
    pretender.post(UPLOAD_URL, async () => {
      requested = true;
      await new Promise(() => {});
    });

    const upload = new UppyUpload(this.parent, {
      id: "uppy-upload-attach-test",
      type: "composer",
      uploadDone: () => {},
    });

    upload.attachFileInput(this.fileInput);
    const uppyInstance = upload.uppyWrapper.uppyInstance;

    await upload.addFiles([createFile(SIBLING_FILE)]);
    await waitUntil(() => requested, { timeout: 5000 });
    const addFiles = sinon.stub(uppyInstance, "addFiles");

    upload.detachFileInput(this.fileInput);
    const newInput = document.createElement("input");
    newInput.type = "file";
    upload.attachFileInput(newInput);

    assert.strictEqual(
      upload.uppyWrapper.uppyInstance,
      uppyInstance,
      "keeps the Uppy instance"
    );
    assert.true(upload.uploading, "keeps uploading");

    await triggerEvent(this.fileInput, "change", {
      files: [createFile("old.png")],
    });
    assert.false(addFiles.called, "unbinds the old input");

    await triggerEvent(newInput, "change", {
      files: [createFile("new.png")],
    });
    assert.true(addFiles.calledOnce, "binds the new input");
  });

  test("attachFileInput recreates Uppy only when idle", async function (assert) {
    const upload = new UppyUpload(this.parent, {
      id: "uppy-upload-attach-idle-test",
      type: "composer",
      autoStartUploads: false,
      uploadDone: () => {},
    });

    upload.attachFileInput(this.fileInput);
    const previous = upload.uppyWrapper.uppyInstance;
    upload.attachFileInput(this.fileInput);
    const uppyInstance = upload.uppyWrapper.uppyInstance;

    assert.notStrictEqual(uppyInstance, previous, "recreates an idle instance");

    await upload.addFiles([createFile(SIBLING_FILE)]);
    upload.attachFileInput(this.fileInput);

    assert.strictEqual(
      upload.uppyWrapper.uppyInstance,
      uppyInstance,
      "keeps an instance with queued files"
    );
    assert.strictEqual(
      uppyInstance.getFiles().length,
      1,
      "keeps the queued file"
    );
  });

  test("teardown is a no-op before setup", function (assert) {
    const unsubscribe = sinon.spy(
      getOwner(this).lookup("service:message-bus"),
      "unsubscribe"
    );
    const upload = new UppyUpload(this.parent, {
      id: "uppy-upload-early-teardown-test",
      type: "composer",
      uploadDone: () => {},
    });

    upload.teardown();

    assert.false(unsubscribe.called, "doesn't unsubscribe from MessageBus");
  });

  test("setup destroys the previous Uppy instance", function (assert) {
    const upload = new UppyUpload(this.parent, {
      id: "uppy-upload-setup-again-test",
      type: "composer",
      uploadDone: () => {},
    });

    upload.setup(this.fileInput);
    const previous = upload.uppyWrapper.uppyInstance;
    const uppyDestroy = sinon.spy(previous, "destroy");
    upload.setup(this.fileInput);

    assert.true(uppyDestroy.calledOnce, "destroys the previous instance");
    assert.notStrictEqual(
      upload.uppyWrapper.uppyInstance,
      previous,
      "creates a new instance"
    );
  });
});
