import Sharing from "discourse/lib/sharing";

QUnit.module("lib:sharing", {
  beforeEach() {
    Sharing._reset();
  }
});

QUnit.test("addSource", assert => {
  const sharingSettings = "facebook|twitter";

  assert.blank(Sharing.activeSources(sharingSettings));

  Sharing.addSource({
    id: "facebook"
  });

  assert.equal(Sharing.activeSources(sharingSettings).length, 1);
});

QUnit.test("addSharingId", assert => {
  const sharingSettings = "";

  assert.blank(Sharing.activeSources(sharingSettings));

  Sharing.addSource({
    id: "new-source"
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
});
