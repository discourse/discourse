import { click, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("draft-icon transformer", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/drafts.json", () =>
      helper.response({
        drafts: [
          {
            draft_key: "new_private_message",
            sequence: 0,
            draft_username: "eviltrout",
            username: "eviltrout",
            user_id: 1,
            data: '{"reply":"hello","action":"privateMessage","title":"A message draft","recipients":"charlie","archetypeId":"private_message"}',
          },
          {
            draft_key: "new_topic",
            sequence: 0,
            draft_username: "eviltrout",
            username: "eviltrout",
            user_id: 1,
            data: '{"reply":"hello","action":"createTopic","title":"A topic draft","archetypeId":"regular"}',
          },
        ],
      })
    );
  });

  async function openDraftsMenu() {
    updateCurrentUser({ draft_count: 2 });

    await visit("/");
    await click("button.topic-drafts-menu-trigger");
    await waitFor(".topic-drafts-menu-content");
  }

  test("renders the default icons", async function (assert) {
    await openDraftsMenu();

    assert.dom(".topic-drafts-item:first-child svg.d-icon-envelope").exists();
    assert.dom(".topic-drafts-item:last-child svg.d-icon-layer-group").exists();
  });

  test("uses the icon returned by the transformer", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("draft-icon", () => "star");
    });

    await openDraftsMenu();

    assert.dom(".topic-drafts-item:first-child svg.d-icon-star").exists();
    assert.dom(".topic-drafts-item:last-child svg.d-icon-star").exists();
  });

  test("the transformer receives the draft as context", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("draft-icon", ({ value, context }) => {
        return context.draft.draft_key === "new_private_message"
          ? "star"
          : value;
      });
    });

    await openDraftsMenu();

    assert
      .dom(".topic-drafts-item:first-child svg.d-icon-star")
      .exists("the message draft is transformed");
    assert
      .dom(".topic-drafts-item:last-child svg.d-icon-layer-group")
      .exists("the topic draft keeps the default icon");
  });
});
