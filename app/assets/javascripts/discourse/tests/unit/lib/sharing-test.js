import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Sharing from "discourse/lib/sharing";

module("Unit | Utility | sharing", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    Sharing._reset();
  });

  hooks.afterEach(function () {
    Sharing._reset();
  });

  test("addSource", function (assert) {
    const sharingSettings = "facebook|twitter";

    assert.blank(Sharing.activeSources(sharingSettings));

    Sharing.addSource({
      id: "facebook",
    });

    assert.strictEqual(Sharing.activeSources(sharingSettings).length, 1);
  });

  test("addSharingId", function (assert) {
    const sharingSettings = "";

    assert.blank(Sharing.activeSources(sharingSettings));

    Sharing.addSource({
      id: "new-source",
    });

    assert.blank(
      Sharing.activeSources(sharingSettings),
      "it doesn’t activate a source not in settings"
    );

    Sharing.addSharingId("new-source");

    assert.strictEqual(
      Sharing.activeSources(sharingSettings).length,
      1,
      "it adds sharing id to existing sharing settings"
    );

    const privateContext = true;

    Sharing.addSource({
      id: "another-source",
    });
    Sharing.addSharingId("another-source");

    assert.strictEqual(
      Sharing.activeSources(sharingSettings, privateContext).length,
      0,
      "it does not add a regular source to sources in a private context"
    );

    Sharing.addSource({
      id: "a-private-friendly-source",
      showInPrivateContext: true,
    });
    Sharing.addSharingId("a-private-friendly-source");

    assert.strictEqual(
      Sharing.activeSources(sharingSettings, privateContext).length,
      1,
      "it does not add a regular source to sources in a private context"
    );
  });
});
