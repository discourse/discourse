import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "../helpers/qunit-helpers.js";

acceptance("User Activity / Drafts - empty state", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    const emptyResponse = { drafts: [] };

    server.get("/drafts.json", () => {
      return helper.response(emptyResponse);
    });
  });

  test("It renders the empty state panel", async function (assert) {
    await visit("/u/eviltrout/activity/drafts");
    assert.dom("div.empty-state").exists();
  });
});

acceptance("User Activity / Drafts - visiting another user", function (needs) {
  const currentUser = "eviltrout";
  const anotherUser = "charlie";

  needs.user();

  test("redirects to the current user drafts page", async function (assert) {
    await visit(`/u/${anotherUser}/activity/drafts`);

    assert.strictEqual(currentURL(), `/u/${currentUser}/activity/drafts`);
  });
});

acceptance("User Activity / Drafts - not signed in", function () {
  test("redirects to the login page", async function (assert) {
    await visit("/u/eviltrout/activity/drafts");

    assert.strictEqual(currentURL(), "/latest");
  });
});

acceptance("User Activity / Drafts - discarded", function (needs) {
  needs.user();

  let restored = false;

  needs.pretender((server, helper) => {
    server.get("/discarded_drafts.json", () =>
      helper.response({
        discarded_drafts: [
          {
            id: 42,
            draft_key: "new_topic_1",
            sequence: 0,
            draft_username: "eviltrout",
            username: "eviltrout",
            deleted_at: "2026-10-24T10:00:00.000Z",
            created_at: "2026-10-23T10:00:00.000Z",
            data: JSON.stringify({ title: "Lost post", reply: "Long content" }),
          },
        ],
      })
    );

    server.put("/discarded_drafts/42/restore.json", () => {
      restored = true;
      return helper.response({ draft_key: "new_topic_1", draft_sequence: 0 });
    });

    server.get("/drafts/new_topic_1.json", () =>
      helper.response({
        draft: JSON.stringify({
          title: "Lost post",
          reply: "Long content",
          action: "createTopic",
        }),
        draft_sequence: 0,
      })
    );
  });

  needs.hooks.beforeEach(() => (restored = false));

  test("lists discarded drafts and restores one into the composer", async function (assert) {
    await visit("/u/eviltrout/activity/drafts/discarded");

    assert.dom(".user-drafts-header__description").exists();
    assert.dom(".user-stream-item").exists({ count: 1 });
    assert.dom(".user-stream-item .resume-draft").doesNotExist();

    await click(".user-stream-item .restore-draft");

    assert.true(restored, "restores the draft on the server");
    assert.dom(".user-stream-item").doesNotExist();
    assert.dom("#reply-control .d-editor-input").hasValue("Long content");
  });
});
