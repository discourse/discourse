import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";

const revisionResponse = {
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
};
acceptance(
  "Edit Notification Click - when post revisions are present",
  function (needs) {
    needs.user();
    needs.pretender((server, helper) => {
      const topicRef = "/t/130.json";
      const topicResponse = cloneJSON(topicFixtures[topicRef]);
      const originalPost = topicResponse.post_stream.posts[0];
      originalPost.version = 2;
      server.get(topicRef, () => helper.response(topicResponse));

      server.get(`/posts/${originalPost.id}/revisions/1.json`, () => {
        return helper.response(revisionResponse);
      });
    });

    test("history modal is shown when navigating from a non-topic page", async function (assert) {
      await visit("/");
      await click(".header-dropdown-toggle.current-user button");
      await click(".notification.edited a");
      const [v1, v2] = queryAll(".history-modal .revision-content");

      assert
        .dom(v1)
        .hasText(
          "Hello world this is a test",
          "history modal for the edited post is shown"
        );

      assert
        .dom(v2)
        .hasText(
          "Hello world this is a testThis is an edit!",
          "history modal for the edited post is shown"
        );
    });
  }
);

acceptance(
  "Edit Notification Click - when post has no revisions",
  function (needs) {
    needs.user();
    needs.pretender((server, helper) => {
      const topicRef = "/t/130.json";
      const topicResponse = cloneJSON(topicFixtures[topicRef]);
      const originalPost = topicResponse.post_stream.posts[0];
      originalPost.version = 1;
      originalPost.can_view_edit_history = true;
      server.get(topicRef, () => helper.response(topicResponse));
      server.get(`/posts/${originalPost.id}/revisions/1.json`, () => {
        return helper.response(revisionResponse);
      });
    });

    test("history modal is not shown when navigating from a non-topic page", async function (assert) {
      await visit("/");
      await click(".header-dropdown-toggle.current-user button");
      await click(".notification.edited a");
      assert
        .dom(".history-modal")
        .doesNotExist(
          "history modal should not open for post on its first version"
        );
    });
  }
);

acceptance(
  "Edit Notification Click - when post edit history cannot be viewed",
  function (needs) {
    needs.user();
    needs.pretender((server, helper) => {
      const topicRef = "/t/130.json";
      const topicResponse = cloneJSON(topicFixtures[topicRef]);
      const originalPost = topicResponse.post_stream.posts[0];
      originalPost.version = 2;
      originalPost.can_view_edit_history = false;
      server.get(topicRef, () => helper.response(topicResponse));
      server.get(`/posts/${originalPost.id}/revisions/1.json`, () => {
        return helper.response(revisionResponse);
      });
    });

    test("history modal is not shown when navigating from a non-topic page", async function (assert) {
      await visit("/");
      await click(".header-dropdown-toggle.current-user button");
      await click(".notification.edited a");
      assert
        .dom(".history-modal")
        .doesNotExist(
          "history modal should not open for post which cannot have edit history viewed"
        );
    });
  }
);
