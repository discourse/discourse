import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import loadUppy from "discourse/lib/load-uppy";
import UppyComposerUpload from "discourse/lib/uppy/composer-upload";
import { createFile } from "discourse/tests/helpers/qunit-helpers";

function fakeComposerModel() {
  return { privateMessage: false };
}

function buildUploader(context, UploaderClass = UppyComposerUpload) {
  return new UploaderClass(getOwner(context), {
    composerEventPrefix: "composer",
    composerModel: fakeComposerModel(),
    uploadMarkdownResolvers: [],
    uploadPreProcessors: [],
    uploadHandlers: [],
    fileUploadElementId: "file-uploader",
  });
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

  hooks.beforeEach(async function () {
    await loadUppy();
  });

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
  });

  hooks.afterEach(function () {
    this.fileInput.remove();
    this.formEl.remove();
    sinon.restore();
  });

  test("_pasteEventListener accepts paste from descendants of .d-editor-input", function (assert) {
    const uploader = buildUploader(this);
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
      const uploader = buildUploader(this);
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
    const uploader = buildUploader(this);
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

  test("setup remains synchronous for lifecycle overrides", function (assert) {
    class CustomUploader extends UppyComposerUpload {
      setup(element) {
        const result = super.setup(element);
        assert.strictEqual(
          result,
          undefined,
          "setup does not return a pending promise"
        );
        const instance = this.uppyWrapper.uppyInstance;
        assert.notStrictEqual(
          instance,
          null,
          "the instance is ready immediately after super.setup"
        );
        instance.opts.onBeforeFileAdded = () => false;
      }
    }

    const uploader = buildUploader(this, CustomUploader);
    uploader.setup(this.formEl);
    assert.false(
      uploader.uppyWrapper.uppyInstance.opts.onBeforeFileAdded(),
      "the lifecycle override can install an upload restriction synchronously"
    );
    uploader.teardown();
  });

  test("setup() called twice tears down the first binding", function (assert) {
    const uploader = buildUploader(this);

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

    uploader.teardown();
  });
});
