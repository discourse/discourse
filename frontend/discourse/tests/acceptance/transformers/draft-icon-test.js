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
            data: '{"title":"A message draft"}',
          },
          { draft_key: "new_topic", data: '{"title":"A topic draft"}' },
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

  test("uses the icon returned by the transformer for the draft it receives", async function (assert) {
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
