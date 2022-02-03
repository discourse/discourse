import UppyChecksum from "discourse/lib/uppy-checksum-plugin";
import { module, skip, test } from "qunit";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
import sinon from "sinon";

class FakeUppy {
  constructor() {
    this.preprocessors = [];
    this.emitted = [];
    this.files = {
      "uppy-test/file/vv2/xvejg5w/blah/png-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764": {
        meta: {},
        data: createFile("test1.png", "image/png", "testblobdata1"),
        size: 1024,
      },
      "uppy-test/file/blah1/ads37x2/blah1/png-1d-1d-2v-1d-1e-image/jpeg-99999-1837921727764": {
        meta: {},
        data: createFile("test2.png", "image/png", "testblobdata2"),
        size: 2048,
      },
      "uppy-test/file/mnb3/jfhrg43x/blah3/png-1d-1d-2v-1d-1e-image/jpeg-111111-1837921727764": {
        meta: {},
        data: createFile("test2.png", "image/png", "testblobdata2"),
        size: 209715200,
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

  setFileMeta(fileId, meta) {
    this.files[fileId].meta = meta;
  }
}

let withCrypto = window.crypto.subtle ? test : skip;

module("Unit | Utility | UppyChecksum Plugin", function () {
  test("sets the options passed in", function (assert) {
    const capabilities = {};
    const fakeUppy = new FakeUppy();
    const plugin = new UppyChecksum(fakeUppy, {
      capabilities,
    });
    assert.strictEqual(plugin.id, "uppy-checksum");
    assert.strictEqual(plugin.capabilities, capabilities);
  });

  withCrypto(
    "it does nothing if not running in a secure context",
    function (assert) {
      const capabilities = {};
      const fakeUppy = new FakeUppy();
      const plugin = new UppyChecksum(fakeUppy, {
        capabilities,
      });
      plugin.install();

      sinon.stub(plugin, "_secureContext").returns(false);

      const fileId =
        "uppy-test/file/vv2/xvejg5w/blah/png-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764";
      return plugin.uppy.preprocessors[0]([fileId]).then(() => {
        assert.strictEqual(
          plugin.uppy.emitted.length,
          1,
          "only the complete event was fired by the checksum plugin because it skipped the file"
        );
      });
    }
  );

  withCrypto(
    "it does nothing if the crypto object + cipher is not available",
    function (assert) {
      const capabilities = {};
      const fakeUppy = new FakeUppy();
      const plugin = new UppyChecksum(fakeUppy, {
        capabilities,
      });
      plugin.install();

      sinon.stub(plugin, "_hasCryptoCipher").returns(false);

      const fileId =
        "uppy-test/file/vv2/xvejg5w/blah/png-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764";
      return plugin.uppy.preprocessors[0]([fileId]).then(() => {
        assert.strictEqual(
          plugin.uppy.emitted.length,
          1,
          "only the complete event was fired by the checksum plugin because it skipped the file"
        );
      });
    }
  );

  test("it does nothing if the browser is IE11", function (assert) {
    const capabilities = { isIE11: true };
    const fakeUppy = new FakeUppy();
    const plugin = new UppyChecksum(fakeUppy, {
      capabilities,
    });
    plugin.install();

    const fileId =
      "uppy-test/file/vv2/xvejg5w/blah/png-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764";
    return plugin.uppy.preprocessors[0]([fileId]).then(() => {
      assert.strictEqual(
        plugin.uppy.emitted.length,
        1,
        "only the complete event was fired by the checksum plugin because it skipped the file"
      );
    });
  });

  withCrypto("it does nothing if the file is > 100MB", function (assert) {
    const capabilities = {};
    const fakeUppy = new FakeUppy();
    const plugin = new UppyChecksum(fakeUppy, {
      capabilities,
    });
    plugin.install();

    const fileId =
      "uppy-test/file/mnb3/jfhrg43x/blah3/png-1d-1d-2v-1d-1e-image/jpeg-111111-1837921727764";
    return plugin.uppy.preprocessors[0]([fileId]).then(() => {
      assert.strictEqual(plugin.uppy.emitted[0].event, "preprocess-progress");
      assert.strictEqual(plugin.uppy.emitted[1].event, "preprocess-complete");
      assert.strictEqual(
        plugin.uppy.getFile(fileId).meta.sha1_checksum,
        undefined
      );
    });
  });

  withCrypto(
    "it gets a sha1 hash of each file and adds it to the file meta",
    function (assert) {
      const capabilities = {};
      const fakeUppy = new FakeUppy();
      const plugin = new UppyChecksum(fakeUppy, {
        capabilities,
      });
      plugin.install();

      const fileIds = [
        "uppy-test/file/vv2/xvejg5w/blah/png-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764",
        "uppy-test/file/blah1/ads37x2/blah1/png-1d-1d-2v-1d-1e-image/jpeg-99999-1837921727764",
      ];
      return plugin.uppy.preprocessors[0](fileIds).then(() => {
        assert.strictEqual(plugin.uppy.emitted[0].event, "preprocess-progress");
        assert.strictEqual(plugin.uppy.emitted[1].event, "preprocess-progress");
        assert.strictEqual(plugin.uppy.emitted[2].event, "preprocess-complete");
        assert.strictEqual(plugin.uppy.emitted[3].event, "preprocess-complete");

        // these checksums are the actual SHA1 hashes of the test file names
        assert.strictEqual(
          plugin.uppy.getFile(fileIds[0]).meta.sha1_checksum,
          "2aa31a700d084c78cecbf030b041ad63eb4f6e8a"
        );
        assert.strictEqual(
          plugin.uppy.getFile(fileIds[1]).meta.sha1_checksum,
          "dfa8c725a5a6710ce4467f29655ec9d26a8de3d0"
        );
      });
    }
  );

  withCrypto(
    "it does nothing if the window.crypto.subtle.digest function throws an error / rejects",
    function (assert) {
      const capabilities = {};
      const fakeUppy = new FakeUppy();
      const plugin = new UppyChecksum(fakeUppy, {
        capabilities,
      });
      plugin.install();

      const fileIds = [
        "uppy-test/file/vv2/xvejg5w/blah/png-1d-1d-2v-1d-1e-image/jpeg-9043429-1624921727764",
        "uppy-test/file/blah1/ads37x2/blah1/png-1d-1d-2v-1d-1e-image/jpeg-99999-1837921727764",
      ];

      sinon
        .stub(window.crypto.subtle, "digest")
        .rejects({ message: "Algorithm: Unrecognized name" });

      return plugin.uppy.preprocessors[0](fileIds).then(() => {
        assert.strictEqual(plugin.uppy.emitted[0].event, "preprocess-progress");
        assert.strictEqual(plugin.uppy.emitted[1].event, "preprocess-progress");
        assert.strictEqual(plugin.uppy.emitted[2].event, "preprocess-complete");
        assert.strictEqual(plugin.uppy.emitted[3].event, "preprocess-complete");

        assert.deepEqual(plugin.uppy.getFile(fileIds[0]).meta, {});
        assert.deepEqual(plugin.uppy.getFile(fileIds[1]).meta, {});
      });
    }
  );
});
