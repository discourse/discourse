import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import UppyWrapper from "discourse/lib/uppy/wrapper";

class FakePreprocessor {
  static pluginId = "fake-preprocessor";
  static pluginType = "preprocessor";
}

class FakeUppy {
  files = {};
  #handlers = {};

  use() {}

  on(event, fn) {
    (this.#handlers[event] ??= []).push(fn);
  }

  emit(event, ...args) {
    this.#handlers[event]?.forEach((fn) => fn(...args));
  }

  getFiles() {
    return Object.values(this.files);
  }

  upload(...files) {
    files.forEach((file) => (this.files[file.id] = file));
    this.emit("upload", "upload-id", files);
  }

  removeFile(id) {
    const file = this.files[id];
    delete this.files[id];
    this.emit("file-removed", file);
  }

  complete(file) {
    this.emit("preprocess-complete", file, false, FakePreprocessor.pluginId);
  }
}

module("Unit | Lib | uppy/wrapper", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.uppy = new FakeUppy();
    this.wrapper = new UppyWrapper(getOwner(this));
    this.wrapper.uppyInstance = this.uppy;
    this.wrapper.useUploadPlugin(FakePreprocessor);

    this.completed = [];
    this.allComplete = 0;
    this.wrapper.onPreProcessComplete(
      (file) => this.completed.push(file.id),
      () => this.allComplete++
    );

    this.a = { id: "a", name: "a.png" };
    this.b = { id: "b", name: "b.png" };
  });

  test("completes once every uploaded file has been preprocessed", function (assert) {
    this.uppy.upload(this.a, this.b);
    this.uppy.complete(this.a);
    assert.strictEqual(this.allComplete, 0, "waits for the second file");

    this.uppy.complete(this.b);
    assert.strictEqual(this.allComplete, 1, "completes after the last file");
    assert.deepEqual(this.completed, ["a", "b"]);
  });

  test("removing the last pending file completes preprocessing", function (assert) {
    this.uppy.upload(this.a, this.b);
    this.uppy.complete(this.a);
    this.uppy.removeFile("b");
    assert.strictEqual(
      this.allComplete,
      1,
      "does not wait on the removed file"
    );

    this.uppy.complete(this.b);
    assert.deepEqual(this.completed, ["a"], "a late event for it is ignored");
    assert.strictEqual(this.allComplete, 1, "and does not complete again");
  });

  test("removing an already preprocessed file does not complete again", function (assert) {
    this.uppy.upload(this.a, this.b);
    this.uppy.complete(this.a);
    this.uppy.complete(this.b);
    this.uppy.removeFile("a");
    assert.strictEqual(this.allComplete, 1);
  });

  test("removing the only file is a cancel-all, not a completion", function (assert) {
    this.uppy.upload(this.a);
    this.uppy.removeFile("a");
    assert.strictEqual(this.allComplete, 0);
  });

  test("ignores events for files that were never uploaded", function (assert) {
    this.uppy.complete(this.a);
    assert.deepEqual(this.completed, []);
    assert.strictEqual(this.allComplete, 0);
  });

  test("starts over when the uppy instance is replaced", function (assert) {
    this.uppy.upload(this.a);

    this.uppy = new FakeUppy();
    this.wrapper.uppyInstance = this.uppy;
    this.wrapper.useUploadPlugin(FakePreprocessor);
    this.wrapper.onPreProcessComplete(
      (file) => this.completed.push(file.id),
      () => this.allComplete++
    );

    this.uppy.upload(this.b);
    this.uppy.complete(this.b);
    assert.deepEqual(this.completed, ["b"], "tracks the new instance's files");
    assert.strictEqual(
      this.allComplete,
      1,
      "completes once, not once per setup"
    );
  });

  test("addNeedProcessing is a deprecated no-op", function (assert) {
    withSilencedDeprecations("discourse.uppy-wrapper-add-need-processing", () =>
      this.wrapper.addNeedProcessing(2)
    );

    this.uppy.upload(this.a);
    this.uppy.complete(this.a);
    assert.strictEqual(this.allComplete, 1, "tracking is unaffected");
  });
});
