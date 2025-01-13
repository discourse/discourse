import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const revisionResponse = {
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
    inline: '<div class="inline-diff"><div>Welcome to Discourse!</div></div>',
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
};

acceptance("History Modal - authorized", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/posts/419/revisions/latest.json", () => {
      return helper.response(revisionResponse);
    });

    server.get("/posts/419/revisions/1.json", () => {
      return helper.response({
        ...revisionResponse,
        current_revision: 1,
        previous_revision: null,
      });
    });
  });

  test("edit post button", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");
    assert
      .dom(".history-modal #revision-footer-buttons .edit-post")
      .exists("displays the edit post button on the latest revision");
  });

  test("edit post button - not last revision", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");
    await click(".history-modal .previous-revision");
    assert
      .dom(".history-modal #revision-footer-buttons .edit-post")
      .doesNotExist(
        "hides the edit post button when not on the latest revision"
      );
  });

  test("previous revision button", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");

    await click(".history-modal .previous-revision");

    assert.dom(".history-modal .previous-revision").isDisabled();
  });
});

acceptance("History Modal - anonymous", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/posts/419/revisions/latest.json", () => {
      return helper.response({ ...revisionResponse, can_edit: false });
    });
  });

  test("edit post button", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");
    assert
      .dom(".history-modal #revision-footer-buttons .edit-post")
      .doesNotExist(
        "it should not display edit button when user cannot edit the post"
      );
  });
});

acceptance("History Modal - not found", function (needs) {
  needs.pretender((server, helper) => {
    const json = cloneJSON(topicFixtures["/t/280/1.json"]);
    json.post_stream.posts[0].version = 2;
    json.post_stream.posts[0].can_view_edit_history = true;

    server.get("/t/280.json", () => helper.response(json));
    server.get("/t/280/:post_number.json", () => {
      helper.response(json);
    });

    server.get("/posts/398/revisions/latest.json", () => {
      return helper.response(404, {
        errors: ["The requested URL or resource could not be found."],
        error_type: "not_found",
      });
    });
  });

  test("try to view a nonexistent revision", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='398'] .edits button");
    assert.dom(".dialog-body").exists();
    await click(".dialog-footer .btn-primary");

    assert
      .dom("article[data-post-id='398'] .edits button")
      .doesNotExist("it should refresh the post to hide the revisions button");
  });
});
