import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";

class FakeUppy {
  constructor() {
    this.preprocessors = [];
    this.emitted = [];
    this.files = {
      "uppy-test/file/vv2/xvejg5w/blah/jpg-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764":
        {
          id: "uppy-test/file/vv2/xvejg5w/blah/jpg-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764",
          data: "old file state",
        },
      "uppy-test/file/blah1/ads37x2/blah1/jpg-1d-1d-2v-1d-1e-image/jpeg-99999-1837921727764":
        {
          id: "uppy-test/file/blah1/ads37x2/blah1/jpg-1d-1d-2v-1d-1e-image/jpeg-99999-1837921727764",
          data: "old file state 1",
        },
    };
  }

  addPreProcessor(fn) {
    this.preprocessors.push(fn);
  }

  on(event, fn) {
    this.handlers ??= {};
    (this.handlers[event] ??= []).push(fn);
  }

  off() {}

  removeFile(id) {
    const file = this.files[id];
    delete this.files[id];
    this.handlers["file-removed"]?.forEach((fn) => fn(file));
  }

  getFile(id) {
    return this.files[id];
  }

  emit(event, file, data) {
    this.emitted.push({ event, file, data });
  }

  setFileState(fileId, state) {
    this.files[fileId] = state;
  }
}

module("Unit | Utility | UppyMediaOptimization Plugin", function (hooks) {
  setupTest(hooks);

  test("sets the options passed in", function (assert) {
    const fakeUppy = new FakeUppy();
    const plugin = new UppyMediaOptimization(fakeUppy, {
      runParallel: true,
      optimizeFn: function () {
        return "wow such optimized";
      },
    });
    assert.strictEqual(plugin.id, "uppy-media-optimization");
    assert.true(plugin.runParallel);
    assert.strictEqual(plugin.optimizeFn(), "wow such optimized");
  });

  test("installation uses the correct function", function (assert) {
    const fakeUppy = new FakeUppy();
    const plugin = new UppyMediaOptimization(fakeUppy, {
      runParallel: true,
    });

    Object.defineProperty(plugin, "_optimizeParallel", {
      value: () => "using parallel",
    });

    Object.defineProperty(plugin, "_optimizeSerial", {
      value: () => "using serial",
    });

    plugin.install();
    assert.strictEqual(plugin.uppy.preprocessors[0](), "using parallel");
    plugin.runParallel = false;
    plugin.uppy.preprocessors = [];
    plugin.install();
    assert.strictEqual(plugin.uppy.preprocessors[0](), "using serial");
  });

  test("sets the file state when successfully optimizing the file and emits events", function (assert) {
    const fakeUppy = new FakeUppy();
    const plugin = new UppyMediaOptimization(fakeUppy, {
      runParallel: true,
      optimizeFn: async () => "new file state",
    });
    plugin.install();
    const done = assert.async();
    const fileId =
      "uppy-test/file/vv2/xvejg5w/blah/jpg-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764";

    plugin.uppy.preprocessors[0]([fileId]).then(() => {
      assert.strictEqual(plugin.uppy.emitted[0].event, "preprocess-progress");
      assert.strictEqual(plugin.uppy.emitted[1].event, "preprocess-complete");
      assert.strictEqual(plugin.uppy.getFile(fileId).data, "new file state");
      done();
    });
  });

  test("handles optimizer errors gracefully by leaving old file state and calling preprocess-complete", function (assert) {
    const fakeUppy = new FakeUppy();
    const plugin = new UppyMediaOptimization(fakeUppy, {
      runParallel: true,
      optimizeFn: async () => {
        throw new Error("bad stuff");
      },
    });
    plugin.install();
    const done = assert.async();
    const fileId =
      "uppy-test/file/vv2/xvejg5w/blah/jpg-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764";

    plugin.uppy.preprocessors[0]([fileId]).then(() => {
      assert.strictEqual(plugin.uppy.emitted[0].event, "preprocess-progress");
      assert.strictEqual(plugin.uppy.emitted[1].event, "preprocess-complete");
      assert.strictEqual(plugin.uppy.getFile(fileId).data, "old file state");
      done();
    });
  });

  test("handles serial file optimization successfully", function (assert) {
    const fakeUppy = new FakeUppy();
    const plugin = new UppyMediaOptimization(fakeUppy, {
      runParallel: false,
      optimizeFn: async () => "new file state",
    });
    plugin.install();
    const done = assert.async();
    const fileIds = [
      "uppy-test/file/vv2/xvejg5w/blah/jpg-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764",
      "uppy-test/file/blah1/ads37x2/blah1/jpg-1d-1d-2v-1d-1e-image/jpeg-99999-1837921727764",
    ];

    plugin.uppy.preprocessors[0](fileIds).then(() => {
      assert.strictEqual(plugin.uppy.emitted[0].event, "preprocess-progress");
      assert.strictEqual(plugin.uppy.emitted[1].event, "preprocess-complete");
      assert.strictEqual(plugin.uppy.emitted[2].event, "preprocess-progress");
      assert.strictEqual(plugin.uppy.emitted[3].event, "preprocess-complete");
      assert.strictEqual(
        plugin.uppy.getFile(fileIds[0]).data,
        "new file state"
      );
      assert.strictEqual(
        plugin.uppy.getFile(fileIds[1]).data,
        "new file state"
      );
      done();
    });
  });

  test("handles parallel file optimization successfully", function (assert) {
    const fakeUppy = new FakeUppy();
    const plugin = new UppyMediaOptimization(fakeUppy, {
      runParallel: true,
      optimizeFn: async () => "new file state",
    });
    plugin.install();
    const done = assert.async();
    const fileIds = [
      "uppy-test/file/vv2/xvejg5w/blah/jpg-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764",
      "uppy-test/file/blah1/ads37x2/blah1/jpg-1d-1d-2v-1d-1e-image/jpeg-99999-1837921727764",
    ];

    plugin.uppy.preprocessors[0](fileIds).then(() => {
      assert.strictEqual(plugin.uppy.emitted[0].event, "preprocess-progress");
      assert.strictEqual(plugin.uppy.emitted[1].event, "preprocess-progress");
      assert.strictEqual(plugin.uppy.emitted[2].event, "preprocess-complete");
      assert.strictEqual(plugin.uppy.emitted[3].event, "preprocess-complete");
      assert.strictEqual(
        plugin.uppy.getFile(fileIds[0]).data,
        "new file state"
      );
      assert.strictEqual(
        plugin.uppy.getFile(fileIds[1]).data,
        "new file state"
      );
      done();
    });
  });

  test("a file removed mid-optimization settles the batch without completing it", async function (assert) {
    const fakeUppy = new FakeUppy();
    const cancelled = [];
    const plugin = new UppyMediaOptimization(fakeUppy, {
      runParallel: true,
      optimizeFn: () => new Promise(() => {}),
      cancelFn: (fileId) => cancelled.push(fileId),
    });
    plugin.install();
    const fileId =
      "uppy-test/file/vv2/xvejg5w/blah/jpg-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764";

    const batch = plugin.uppy.preprocessors[0]([fileId]);
    fakeUppy.removeFile(fileId);
    await batch;

    assert.deepEqual(
      plugin.uppy.emitted.map((e) => e.event),
      ["preprocess-progress"],
      "no completion is emitted for the removed file"
    );
    assert.deepEqual(cancelled, [fileId], "the optimizer is told to cancel");
  });

  test("serial optimization skips files removed before their turn", async function (assert) {
    const fakeUppy = new FakeUppy();
    const resolvers = {};
    const plugin = new UppyMediaOptimization(fakeUppy, {
      runParallel: false,
      optimizeFn: (file) =>
        new Promise((resolve) => (resolvers[file.id] = resolve)),
    });
    plugin.install();
    const [first, second] = Object.keys(fakeUppy.files);

    const batch = plugin.uppy.preprocessors[0]([first, second]);
    fakeUppy.removeFile(second);
    resolvers[first]("new file state");
    await batch;

    assert.deepEqual(
      plugin.uppy.emitted.map((e) => [e.event, e.file.id]),
      [
        ["preprocess-progress", first],
        ["preprocess-complete", first],
      ],
      "only the remaining file is processed"
    );
  });
});
