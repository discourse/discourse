import { destroy } from "@ember/destroyable";
import { getOwner, setOwner } from "@ember/owner";
import { run } from "@ember/runloop";
import { waitUntil } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import UppyComposerUpload from "discourse/lib/uppy/composer-upload";
import { UploadPreProcessorPlugin } from "discourse/lib/uppy-plugin-base";
import pretender from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";

class PassThroughPreProcessor extends UploadPreProcessorPlugin {
  static pluginId = "pass-through-preprocessor";

  _process = (fileIds) => this._emitAllComplete(fileIds);

  install() {
    this._install(this._process);
  }
}

function fakeComposerModel() {
  return { privateMessage: false };
}

function buildUploader(parent, uploadPreProcessors = []) {
  return new UppyComposerUpload(parent, {
    composerEventPrefix: "composer",
    composerModel: fakeComposerModel(),
    uploadMarkdownResolvers: [],
    uploadPreProcessors,
    uploadHandlers: [],
    fileUploadElementId: "file-uploader",
  });
}

function fakeTextManipulation() {
  const noop = () => {};
  return {
    autoGridImages: noop,
    placeholder: {
      insert: noop,
      progress: noop,
      progressComplete: noop,
      success: noop,
      cancel: noop,
      cancelAll: noop,
    },
  };
}

function buildPasteEvent(target, files) {
  const event = new Event("paste", { cancelable: true, bubbles: true });
  Object.defineProperty(event, "target", { value: target });
  event.clipboardData = {
    types: ["Files"],
    files,
    items: [],
    getData: () => "",
  };
  return event;
}

module("Unit | Lib | uppy/composer-upload", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.fileInput = document.createElement("input");
    this.fileInput.type = "file";
    this.fileInput.id = "file-uploader";
    document.body.appendChild(this.fileInput);

    this.formEl = document.createElement("form");
    this.editorInput = document.createElement("textarea");
    this.editorInput.className = "d-editor-input";
    this.formEl.appendChild(this.editorInput);
    document.body.appendChild(this.formEl);

    this.parent = {};
    setOwner(this.parent, getOwner(this));
  });

  hooks.afterEach(function () {
    run(() => destroy(this.parent));
    this.fileInput.remove();
    this.formEl.remove();
    sinon.restore();
  });

  test("_pasteEventListener accepts paste from descendants of .d-editor-input", function (assert) {
    const uploader = buildUploader(this.parent);
    uploader.uppyWrapper.uppyInstance = { addFiles: sinon.spy() };

    const nested = document.createElement("span");
    this.editorInput.appendChild(nested);

    const file = createFile("paste.png", "image/png", "data");
    const event = buildPasteEvent(nested, [file]);
    uploader._pasteEventListener(event);

    assert.true(
      event.defaultPrevented,
      "paste from a nested element inside .d-editor-input is captured"
    );
  });

  test("_pasteEventListener accepts paste from a non-first .d-editor-input", function (assert) {
    const earlierInput = document.createElement("textarea");
    earlierInput.className = "d-editor-input";
    document.body.insertBefore(earlierInput, this.formEl);

    try {
      const uploader = buildUploader(this.parent);
      uploader.uppyWrapper.uppyInstance = { addFiles: sinon.spy() };

      const file = createFile("paste.png", "image/png", "data");
      const event = buildPasteEvent(this.editorInput, [file]);
      uploader._pasteEventListener(event);

      assert.true(
        event.defaultPrevented,
        "paste from the second .d-editor-input is captured (closest() walks up from target, not document.querySelector)"
      );
    } finally {
      earlierInput.remove();
    }
  });

  test("_pasteEventListener ignores paste outside .d-editor-input", function (assert) {
    const uploader = buildUploader(this.parent);
    uploader.uppyWrapper.uppyInstance = { addFiles: sinon.spy() };

    const outside = document.createElement("div");
    document.body.appendChild(outside);

    const file = createFile("paste.png", "image/png", "data");
    const event = buildPasteEvent(outside, [file]);
    uploader._pasteEventListener(event);

    assert.false(
      event.defaultPrevented,
      "paste outside .d-editor-input is not captured"
    );

    outside.remove();
  });

  test("setup() called twice tears down the first binding", function (assert) {
    const uploader = buildUploader(this.parent);

    uploader.setup(this.formEl);
    const firstUppy = uploader.uppyWrapper.uppyInstance;
    assert.notStrictEqual(
      firstUppy,
      null,
      "first setup creates an Uppy instance"
    );

    const teardownSpy = sinon.spy(uploader, "teardown");

    uploader.setup(this.formEl);
    assert.true(teardownSpy.calledOnce, "teardown is called once on re-setup");

    assert.notStrictEqual(
      firstUppy,
      uploader.uppyWrapper.uppyInstance,
      "second setup replaces the Uppy instance"
    );
  });

  test("preprocessing completes once per batch after setup() is re-run", async function (assert) {
    pretender.post("/uploads.json", (request) => [
      200,
      { "Content-Type": "application/json" },
      JSON.stringify({
        id: 1,
        url: "/uploads/avatar.png",
        short_url: "upload://avatar.png",
        original_filename: request.requestBody.get("file").name,
      }),
    ]);

    const uploader = buildUploader(this.parent, [
      { pluginClass: PassThroughPreProcessor, optionsResolverFn: () => ({}) },
    ]);
    uploader.textManipulation = fakeTextManipulation();

    const appEvents = getOwner(this).lookup("service:app-events");
    let preprocessedBatches = 0;
    let uploadsComplete = false;
    appEvents.on("composer:uploads-preprocessing-complete", () => {
      preprocessedBatches++;
    });
    appEvents.one("composer:all-uploads-complete", () => {
      uploadsComplete = true;
    });

    uploader.setup(this.formEl);
    uploader.setup(this.formEl);
    await uploader._addFiles([createFile("avatar.png")]);
    await waitUntil(() => uploadsComplete, { timeout: 5000 });

    assert.strictEqual(
      preprocessedBatches,
      1,
      "the rebuilt uploader reports preprocessing complete exactly once"
    );
  });

  test("destroying the parent tears down", function (assert) {
    const uploader = buildUploader(this.parent);
    uploader.setup(this.formEl);
    const uppyDestroy = sinon.spy(uploader.uppyWrapper.uppyInstance, "destroy");

    run(() => destroy(this.parent));

    assert.true(uppyDestroy.calledOnce, "destroys the Uppy instance");
  });

  test("teardown can run more than once", function (assert) {
    const uploader = buildUploader(this.parent);
    uploader.setup(this.formEl);

    uploader.teardown();
    uploader.teardown();

    assert.strictEqual(
      uploader.uppyWrapper.uppyInstance,
      null,
      "leaves no Uppy instance"
    );
  });

  test("still accepts an owner", function (assert) {
    const owner = getOwner(this);
    const uploader = withSilencedDeprecations(
      "discourse.uppy-composer-upload-owner",
      () => buildUploader(owner)
    );

    assert.strictEqual(getOwner(uploader), owner, "uses it as the owner");
  });
});
