import { click, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Voice transcript draft icon", function (needs) {
  needs.user();
  needs.settings({ voice_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/voice/rooms.json", () =>
      helper.response({ rooms: [], can_create_room: false })
    );
    server.get("/drafts.json", () =>
      helper.response({
        drafts: [
          {
            draft_key: "new_topic_voice_1_1756400000000",
            data: '{"title":"Sala do Bar — transcript"}',
          },
          { draft_key: "new_topic", data: '{"title":"A topic draft"}' },
        ],
      })
    );
  });

  test("transcript drafts get the transcript icon, others keep theirs", async function (assert) {
    updateCurrentUser({ draft_count: 2 });

    await visit("/");
    await click("button.topic-drafts-menu-trigger");
    await waitFor(".topic-drafts-menu-content");

    assert
      .dom(".topic-drafts-item:first-child svg.d-icon-closed-captioning")
      .exists("the transcript draft uses the transcript icon");
    assert
      .dom(".topic-drafts-item:last-child svg.d-icon-layer-group")
      .exists("an ordinary topic draft keeps the default icon");
  });
});
