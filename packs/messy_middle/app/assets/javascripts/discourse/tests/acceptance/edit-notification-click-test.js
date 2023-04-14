import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Edit Notification Click", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/posts/133/revisions/1.json", () => {
      return helper.response({
        created_at: "2021-07-30T11:19:59.549Z",
        post_id: 133,
        previous_hidden: false,
        current_hidden: false,
        first_revision: 2,
        previous_revision: null,
        current_revision: 2,
        next_revision: null,
        last_revision: 2,
        current_version: 2,
        version_count: 2,
        username: "velesin",
        display_username: "velesin",
        avatar_template: "/letter_avatar_proxy/v4/letter/j/13edae/{size}.png",
        edit_reason: null,
        body_changes: {
          inline:
            '<div class="inline-diff"><p>Hello world this is a test</p><p class="diff-ins">another edit!</p></div>',
          side_by_side:
            '<div class="revision-content"><p>Hello world this is a test</p></div><div class="revision-content"><p>Hello world this is a test</p><p class="diff-ins">This is an edit!</p></div>',
          side_by_side_markdown:
            '<table class="markdown"><tr><td class="diff-del">Hello world this is a test</td><td class="diff-ins">Hello world this is a test<ins>\n\nThis is an edit!</ins></td></tr></table>',
        },
        title_changes: null,
        user_changes: null,
        wiki: false,
        can_edit: true,
      });
    });
  });

  test("history modal is shown when navigating from a non-topic page", async function (assert) {
    await visit("/");
    await click(".d-header-icons #current-user");
    await click("#quick-access-notifications .edited");
    const [v1, v2] = queryAll(".history-modal .revision-content");
    assert.strictEqual(
      v1.textContent.trim(),
      "Hello world this is a test",
      "history modal for the edited post is shown"
    );
    assert.strictEqual(
      v2.textContent.trim(),
      "Hello world this is a testThis is an edit!",
      "history modal for the edited post is shown"
    );
  });
});
