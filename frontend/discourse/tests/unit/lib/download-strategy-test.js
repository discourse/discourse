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

  test("returns 'bridge' in an app webview", function (assert) {
    sinon.stub(capabilities, "isAppWebview").value(true);
    sinon.stub(capabilities, "isPwa").value(false);

    assert.strictEqual(attachmentDownloadStrategy(), "bridge");
  });

  test("returns 'blob' in a PWA", function (assert) {
    sinon.stub(capabilities, "isAppWebview").value(false);
    sinon.stub(capabilities, "isPwa").value(true);

    assert.strictEqual(attachmentDownloadStrategy(), "blob");
  });
});
