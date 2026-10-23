import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { attachmentDownloadStrategy } from "discourse/lib/download-strategy";
import { capabilities } from "discourse/services/capabilities";

module("Unit | Utility | download-strategy", function (hooks) {
  setupTest(hooks);

  test("returns 'native' by default", function (assert) {
    sinon.stub(capabilities, "isPwa").value(false);

    assert.strictEqual(attachmentDownloadStrategy(), "native");
  });

  test("returns 'bridge' on iOS once the Hub app confirms bridge support", function (assert) {
    sinon.stub(capabilities, "isAppWebview").value(true);
    sinon.stub(capabilities, "isIOS").value(true);
    sinon.stub(capabilities, "hubDownloadBridgeSupported").value(true);
    sinon.stub(capabilities, "isPwa").value(false);

    assert.strictEqual(attachmentDownloadStrategy(), "bridge");
  });

  test("returns 'native' in an Android app webview", function (assert) {
    sinon.stub(capabilities, "isAppWebview").value(true);
    sinon.stub(capabilities, "isIOS").value(false);
    sinon.stub(capabilities, "hubDownloadBridgeSupported").value(true);
    sinon.stub(capabilities, "isPwa").value(false);

    assert.strictEqual(attachmentDownloadStrategy(), "native");
  });

  test("returns 'native' on iOS when the Hub app hasn't shipped bridge support yet", function (assert) {
    sinon.stub(capabilities, "isAppWebview").value(true);
    sinon.stub(capabilities, "isIOS").value(true);
    sinon.stub(capabilities, "hubDownloadBridgeSupported").value(false);
    sinon.stub(capabilities, "isPwa").value(false);

    assert.strictEqual(attachmentDownloadStrategy(), "native");
  });

  test("returns 'blob' in a PWA", function (assert) {
    sinon.stub(capabilities, "isAppWebview").value(false);
    sinon.stub(capabilities, "isPwa").value(true);

    assert.strictEqual(attachmentDownloadStrategy(), "blob");
  });
});
