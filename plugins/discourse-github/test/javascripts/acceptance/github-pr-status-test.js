import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const PR_ONEBOX_HTML = `
<aside class="onebox githubpullrequest" data-onebox-src="https://github.com/discourse/discourse/pull/123">
  <header class="source">
    <a href="https://github.com/discourse/discourse/pull/123" target="_blank" rel="noopener">github.com/discourse/discourse</a>
  </header>
  <article class="onebox-body">
    <div class="github-icon-container"><svg class="github-icon" viewBox="0 0 16 16"></svg></div>
    <h4><a href="https://github.com/discourse/discourse/pull/123" target="_blank" rel="noopener">Test PR Title</a></h4>
    <div class="github-info-container">
      <span class="github-info">#123</span>
    </div>
  </article>
</aside>
`;

function topicWithGithubPrOnebox() {
  return {
    post_stream: {
      posts: [
        {
          id: 1,
          username: "test_user",
          avatar_template: "/letter_avatar_proxy/v2/letter/t/ac91a4/{size}.png",
          created_at: "2024-01-01T00:00:00.000Z",
          cooked: PR_ONEBOX_HTML,
          post_number: 1,
          post_type: 1,
          updated_at: "2024-01-01T00:00:00.000Z",
          reply_count: 0,
          reply_to_post_number: null,
          quote_count: 0,
          incoming_link_count: 0,
          reads: 1,
          score: 0,
          yours: false,
          topic_id: 1,
          topic_slug: "test-topic",
          version: 1,
          can_edit: false,
          can_delete: false,
          can_recover: false,
          can_wiki: false,
          read: true,
          actions_summary: [],
          moderator: false,
          admin: false,
          staff: false,
          user_id: 2,
          hidden: false,
          trust_level: 1,
          deleted_at: null,
          user_deleted: false,
          can_view_edit_history: true,
          wiki: false,
        },
      ],
      stream: [1],
    },
    timeline_lookup: [[1, 0]],
    id: 1,
    title: "Test Topic with GitHub PR",
    fancy_title: "Test Topic with GitHub PR",
    posts_count: 1,
    created_at: "2024-01-01T00:00:00.000Z",
    views: 1,
    reply_count: 0,
    participant_count: 1,
    like_count: 0,
    last_posted_at: "2024-01-01T00:00:00.000Z",
    visible: true,
    closed: false,
    archived: false,
    has_summary: false,
    archetype: "regular",
    slug: "test-topic",
    category_id: 1,
    word_count: 10,
    deleted_at: null,
    user_id: 2,
    draft: null,
    draft_key: "topic_1",
    draft_sequence: 0,
    posted: false,
    pinned_globally: false,
    pinned: false,
    details: {
      created_by: {
        id: 2,
        username: "test_user",
        avatar_template: "/letter_avatar_proxy/v2/letter/t/ac91a4/{size}.png",
      },
      last_poster: {
        id: 2,
        username: "test_user",
        avatar_template: "/letter_avatar_proxy/v2/letter/t/ac91a4/{size}.png",
      },
      participants: [
        {
          id: 2,
          username: "test_user",
          avatar_template: "/letter_avatar_proxy/v2/letter/t/ac91a4/{size}.png",
          post_count: 1,
        },
      ],
      notification_level: 1,
      can_create_post: true,
      can_reply_as_new_topic: true,
      can_flag_topic: true,
    },
    highest_post_number: 1,
    last_read_post_number: 1,
    last_read_post_id: 1,
    has_deleted: false,
    actions_summary: [],
    chunk_size: 20,
    bookmarked: false,
    tags: [],
    message_bus_last_id: 0,
  };
}

acceptance("Discourse GitHub | PR Status", function (needs) {
  needs.user();

  needs.settings({
    enable_discourse_github_plugin: true,
    github_pr_status_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.get("/t/1.json", () => helper.response(topicWithGithubPrOnebox()));

    server.get("/discourse-github/:owner/:repo/pulls/:number/status.json", () =>
      helper.response({ state: "merged" })
    );
  });

  test("applies PR status class to onebox", async function (assert) {
    await visit("/t/test-topic/1");

    assert
      .dom(".onebox.githubpullrequest")
      .hasClass("--gh-status-merged", "onebox has merged status class");

    assert
      .dom(".onebox.githubpullrequest")
      .hasAttribute(
        "data-gh-pr-status",
        "merged",
        "onebox has data attribute with status"
      );
  });

  test("sets title on icon container", async function (assert) {
    await visit("/t/test-topic/1");

    assert
      .dom(".onebox.githubpullrequest .github-icon-container")
      .hasAttribute(
        "title",
        i18n("github.pr_status.merged"),
        "icon container has correct title"
      );
  });
});

acceptance("Discourse GitHub | PR Status - Different States", function (needs) {
  needs.user();

  needs.settings({
    enable_discourse_github_plugin: true,
    github_pr_status_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.get("/t/1.json", () => helper.response(topicWithGithubPrOnebox()));

    server.get("/discourse-github/:owner/:repo/pulls/:number/status.json", () =>
      helper.response({ state: "open" })
    );
  });

  test("applies open status class", async function (assert) {
    await visit("/t/test-topic/1");

    assert
      .dom(".onebox.githubpullrequest")
      .hasClass("--gh-status-open", "onebox has open status class");
  });
});

acceptance("Discourse GitHub | PR Status - Disabled", function (needs) {
  needs.user();

  needs.settings({
    enable_discourse_github_plugin: true,
    github_pr_status_enabled: false,
  });

  needs.pretender((server, helper) => {
    server.get("/t/1.json", () => helper.response(topicWithGithubPrOnebox()));
  });

  test("does not fetch status when disabled", async function (assert) {
    await visit("/t/test-topic/1");

    assert
      .dom(".onebox.githubpullrequest")
      .doesNotHaveClass(
        "--gh-status-merged",
        "onebox does not have status class when disabled"
      );

    assert
      .dom(".onebox.githubpullrequest[data-gh-pr-status]")
      .doesNotExist("onebox does not have data attribute when disabled");
  });
});

acceptance("Discourse GitHub | PR Status - Anonymous User", function (needs) {
  needs.settings({
    enable_discourse_github_plugin: true,
    github_pr_status_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.get("/t/1.json", () => helper.response(topicWithGithubPrOnebox()));
  });

  test("does not fetch status for anonymous users", async function (assert) {
    await visit("/t/test-topic/1");

    assert
      .dom(".onebox.githubpullrequest[data-gh-pr-status]")
      .doesNotExist("onebox does not have data attribute for anonymous users");
  });
});
