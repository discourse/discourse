import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";
import { module, skip } from "qunit";
import { Promise } from "rsvp";

class FakeUppy {
  constructor() {
    this.preprocessors = [];
    this.emitted = [];
    this.files = {
      "uppy-test/file/vv2/xvejg5w/blah/jpg-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764": {
        data: "old file state",
      },
      "uppy-test/file/blah1/ads37x2/blah1/jpg-1d-1d-2v-1d-1e-image/jpeg-99999-1837921727764": {
        data: "old file state 1",
      },
    };
  }

  addPreProcessor(fn) {
    this.preprocessors.push(fn);
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

module("Unit | Utility | UppyMediaOptimization Plugin", function () {
  skip("sets the options passed in", function (assert) {
    const fakeUppy = new FakeUppy();
    const plugin = new UppyMediaOptimization(fakeUppy, {
      id: "test-uppy",
      runParallel: true,
      optimizeFn: function () {
        return "wow such optimized";
      },
    });
    assert.equal(plugin.id, "test-uppy");
    assert.equal(plugin.runParallel, true);
    assert.equal(plugin.optimizeFn(), "wow such optimized");
  });

  skip("installation uses the correct function", function (assert) {
    const fakeUppy = new FakeUppy();
    const plugin = new UppyMediaOptimization(fakeUppy, {
      id: "test-uppy",
      runParallel: true,
    });
    plugin._optimizeParallel = function () {
      return "using parallel";
    };
    plugin._optimizeSerial = function () {
      return "using serial";
    };
    plugin.install();
    assert.equal(plugin.uppy.preprocessors[0](), "using parallel");
    plugin.runParallel = false;
    plugin.uppy.preprocessors = [];
    plugin.install();
    assert.equal(plugin.uppy.preprocessors[0](), "using serial");
  });

  skip("sets the file state when successfully optimizing the file and emits events", function (assert) {
    const fakeUppy = new FakeUppy();
    const plugin = new UppyMediaOptimization(fakeUppy, {
      id: "test-uppy",
      runParallel: true,
      optimizeFn: () => {
        return Promise.resolve("new file state");
      },
    });
    plugin.install();
    const done = assert.async();
    const fileId =
      "uppy-test/file/vv2/xvejg5w/blah/jpg-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764";

    plugin.uppy.preprocessors[0]([fileId]).then(() => {
      assert.equal(plugin.uppy.emitted[0].event, "preprocess-progress");
      assert.equal(plugin.uppy.emitted[1].event, "preprocess-complete");
      assert.equal(plugin.uppy.getFile(fileId).data, "new file state");
      done();
    });
  });

  skip("handles optimizer errors gracefully by leaving old file state and calling preprocess-complete", function (assert) {
    const fakeUppy = new FakeUppy();
    const plugin = new UppyMediaOptimization(fakeUppy, {
      id: "test-uppy",
      runParallel: true,
      optimizeFn: () => {
        return new Promise(() => {
          throw new Error("bad stuff");
        });
      },
    });
    plugin.install();
    const done = assert.async();
    const fileId =
      "uppy-test/file/vv2/xvejg5w/blah/jpg-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764";

    plugin.uppy.preprocessors[0]([fileId]).then(() => {
      assert.equal(plugin.uppy.emitted[0].event, "preprocess-progress");
      assert.equal(plugin.uppy.emitted[1].event, "preprocess-complete");
      assert.equal(plugin.uppy.getFile(fileId).data, "old file state");
      done();
    });
  });

  skip("handles serial file optimization successfully", function (assert) {
    const fakeUppy = new FakeUppy();
    const plugin = new UppyMediaOptimization(fakeUppy, {
      id: "test-uppy",
      runParallel: false,
      optimizeFn: () => {
        return Promise.resolve("new file state");
      },
    });
    plugin.install();
    const done = assert.async();
    const fileIds = [
      "uppy-test/file/vv2/xvejg5w/blah/jpg-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764",
      "uppy-test/file/blah1/ads37x2/blah1/jpg-1d-1d-2v-1d-1e-image/jpeg-99999-1837921727764",
    ];

    plugin.uppy.preprocessors[0](fileIds).then(() => {
      assert.equal(plugin.uppy.emitted[0].event, "preprocess-progress");
      assert.equal(plugin.uppy.emitted[1].event, "preprocess-complete");
      assert.equal(plugin.uppy.emitted[2].event, "preprocess-progress");
      assert.equal(plugin.uppy.emitted[3].event, "preprocess-complete");
      assert.equal(plugin.uppy.getFile(fileIds[0]).data, "new file state");
      assert.equal(plugin.uppy.getFile(fileIds[1]).data, "new file state");
      done();
    });
  });

  skip("handles parallel file optimization successfully", function (assert) {
    const fakeUppy = new FakeUppy();
    const plugin = new UppyMediaOptimization(fakeUppy, {
      id: "test-uppy",
      runParallel: true,
      optimizeFn: () => {
        return Promise.resolve("new file state");
      },
    });
    plugin.install();
    const done = assert.async();
    const fileIds = [
      "uppy-test/file/vv2/xvejg5w/blah/jpg-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764",
      "uppy-test/file/blah1/ads37x2/blah1/jpg-1d-1d-2v-1d-1e-image/jpeg-99999-1837921727764",
    ];

    plugin.uppy.preprocessors[0](fileIds).then(() => {
      assert.equal(plugin.uppy.emitted[0].event, "preprocess-progress");
      assert.equal(plugin.uppy.emitted[1].event, "preprocess-progress");
      assert.equal(plugin.uppy.emitted[2].event, "preprocess-complete");
      assert.equal(plugin.uppy.emitted[3].event, "preprocess-complete");
      assert.equal(plugin.uppy.getFile(fileIds[0]).data, "new file state");
      assert.equal(plugin.uppy.getFile(fileIds[1]).data, "new file state");
      done();
    });
  });
});
