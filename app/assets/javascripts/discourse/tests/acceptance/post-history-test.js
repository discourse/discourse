import { click, visit } from "@ember/test-helpers";
import {
  acceptance,
  count,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

acceptance("Post - History", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/posts/419/revisions/latest.json", () => {
      return helper.response({
        created_at: "2021-11-24T10:59:36.163Z",
        post_id: 419,
        previous_hidden: false,
        current_hidden: false,
        first_revision: 1,
        previous_revision: 1,
        current_revision: 2,
        next_revision: null,
        last_revision: 2,
        current_version: 2,
        version_count: 2,
        username: "bianca",
        display_username: "bianca",
        avatar_template: "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
        edit_reason: null,
        body_changes: {
          inline: '<div class="inline-diff"><p>Welcome to Discourse!</p</div>',
          side_by_side:
            '<div class="revision-content"><p>Welcome to Discourse!</p</div><div class="revision-content"><p>Welcome to Discourse!</p</div>',
          side_by_side_markdown:
            '<table class="markdown"><tr><td>Welcome to Discourse!</td><td>Welcome to Discourse!</td></tr></table>',
        },
        title_changes: {
          inline:
            '<div class="inline-diff"><div>Welcome to Discourse!</div></div>',
          side_by_side:
            '<div class="revision-content"><div>Welcome to Discourse!</div></div><div class="revision-content"><div>Welcome to Discourse!</div></div>',
        },
        user_changes: null,
        tags_changes: {
          previous: ["tag1", "tag2"],
          current: ["tag2", "tag3"],
        },
        wiki: false,
        can_edit: true,
      });
    });
  });

  test("Shows highlighted tag changes", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");
    assert.equal(count(".discourse-tag"), 4);
    assert.equal(count(".discourse-tag.diff-del"), 1);
    assert.equal(query(".discourse-tag.diff-del").textContent, "tag1");
    assert.equal(count(".discourse-tag.diff-ins"), 1);
    assert.equal(query(".discourse-tag.diff-ins").textContent, "tag3");
  });
});
