import Sharing from "discourse/lib/sharing";

QUnit.module("lib:sharing", {
  beforeEach() {
    Sharing._reset();
  },
  afterEach() {
    Sharing._reset();
  },
});

QUnit.test("addSource", (assert) => {
  const sharingSettings = "facebook|twitter";

  assert.blank(Sharing.activeSources(sharingSettings));

  Sharing.addSource({
    id: "facebook",
  });

  assert.equal(Sharing.activeSources(sharingSettings).length, 1);
});

QUnit.test("addSharingId", (assert) => {
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

  assert.equal(
    Sharing.activeSources(sharingSettings).length,
    1,
    "it adds sharing id to existing sharing settings"
  );

  const privateContext = true;

  Sharing.addSource({
    id: "another-source",
  });
  Sharing.addSharingId("another-source");

  assert.equal(
    Sharing.activeSources(sharingSettings, privateContext).length,
    0,
    "it does not add a regular source to sources in a private context"
  );

  Sharing.addSource({
    id: "a-private-friendly-source",
    showInPrivateContext: true,
  });
  Sharing.addSharingId("a-private-friendly-source");

  assert.equal(
    Sharing.activeSources(sharingSettings, privateContext).length,
    1,
    "it does not add a regular source to sources in a private context"
  );
});
