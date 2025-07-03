import { getOwner } from "@ember/owner";
import { click, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import Post from "discourse/components/post";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { count, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import DMenus from "float-kit/components/d-menus";

function renderComponent(
  post,
  {
    prevPost,
    changePostOwner,
    editPost,
    expandHidden,
    permanentlyDeletePost,
    rebakePost,
    showHistory,
    showRawEmail,
    togglePostType,
    unhidePost,
  } = {}
) {
  // TODO (glimmer-post-stream) remove the outer div when the post-stream widget is converted to a Glimmer component
  return render(
    <template>
      <div class="topic-post glimmer-post-stream">
        <Post
          @post={{post}}
          @prevPost={{prevPost}}
          @changePostOwner={{changePostOwner}}
          @editPost={{editPost}}
          @expandHidden={{expandHidden}}
          @permanentlyDeletePost={{permanentlyDeletePost}}
          @rebakePost={{rebakePost}}
          @showHistory={{showHistory}}
          @showRawEmail={{showRawEmail}}
          @togglePostType={{togglePostType}}
          @unhidePost={{unhidePost}}
        />
      </div>
      <DMenus />
    </template>
  );
}

module("Integration | Component | Post", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.glimmer_post_stream_mode = "enabled";
    this.siteSettings.post_menu_hidden_items = "";

    this.store = getOwner(this).lookup("service:store");
    const topic = this.store.createRecord("topic", { id: 123 });
    const post = this.store.createRecord("post", {
      id: 123,
      post_number: 1,
      topic,
      like_count: 3,
      actions_summary: [{ id: 2, count: 1, hidden: false, can_act: true }],
      created_at: new Date(new Date().getTime() - 30 * 60 * 1000),
    });

    this.post = post;
  });

  test("basic elements", async function (assert) {
    await renderComponent(this.post);

    assert.dom(".names").exists("includes poster name");
    assert.dom("a.post-date").exists("includes post date");

    assert
      .dom("a.post-date .relative-date")
      .hasAttribute(
        "data-time",
        this.post.created_at.getTime().toString(10),
        "the relative date has the correct time"
      );
  });

  test("can add classes to the component", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("post-class", ({ value }) => {
        value.push("custom-class");
        return value;
      });

      api.addPostClassesCallback((post) => `api-custom-class-${post.id}`);
    });

    await renderComponent(this.post);

    assert
      .dom(".topic-post.custom-class.api-custom-class-123")
      .exists("applies the custom classes to the component");
  });

  test("links", async function (assert) {
    this.post.link_counts = [
      {
        title: "Link 1",
        url: "/t/1",
        internal: true,
        reflection: true,
        clicks: 2,
      },
    ];

    await renderComponent(this.post);

    assert.dom(".post-links-container").exists("links are displayed");
    assert
      .dom(".post-links a.track-link")
      .exists({ count: 1 }, "hides the dupe link")
      .hasAttribute("data-clicks", "2", "has the correct click count");
  });

  test("post - cooked links", async function (assert) {
    this.post.cooked =
      "<a href='http://link1.example.com/'>first link</a> and <a href='http://link2.example.com/?some=query'>second link</a>";
    this.post.link_counts = [
      { url: "http://link1.example.com/", clicks: 1, internal: true },
      { url: "http://link2.example.com/", clicks: 2, internal: true },
    ];

    await renderComponent(this.post);

    assert.strictEqual(
      queryAll("a[data-clicks='1']")[0].getAttribute("data-clicks"),
      "1"
    );
    assert.strictEqual(
      queryAll("a[data-clicks='2']")[0].getAttribute("data-clicks"),
      "2"
    );
  });

  test("post - cooked onebox links", async function (assert) {
    this.post.cooked = `
      <p><a href="https://example.com">Other URL</a></p>

      <aside class="onebox twitterstatus" data-onebox-src="https://twitter.com/codinghorror">
        <header class="source">
           <a href="https://twitter.com/codinghorror" target="_blank" rel="noopener">twitter.com</a>
        </header>
        <article class="onebox-body">
           <h4><a href="https://twitter.com/codinghorror" target="_blank" rel="noopener">Jeff Atwood</a></h4>
           <div class="twitter-screen-name"><a href="https://twitter.com/codinghorror" target="_blank" rel="noopener">@codinghorror</a></div>
        </article>
      </aside>`;
    this.post.link_counts = [
      { url: "https://example.com", clicks: 1 },
      { url: "https://twitter.com/codinghorror", clicks: 2 },
    ];

    await renderComponent(this.post);

    assert.strictEqual(
      queryAll("a[data-clicks='1']")[0].getAttribute("data-clicks"),
      "1",
      "First link has correct data attribute and content"
    );
    assert.strictEqual(
      queryAll("a[data-clicks='2']")[0].getAttribute("data-clicks"),
      "2",
      "Second link has correct data attribute and content"
    );
  });

  test("wiki", async function (assert) {
    this.post.wiki = true;
    this.post.version = 2;
    this.post.can_view_edit_history = true;
    this.post.last_wiki_edit = new Date();

    await renderComponent(this.post, {
      showHistory: () => assert.step("show history called"),
    });

    assert
      .dom("a.post-date .relative-date")
      .hasAttribute(
        "data-time",
        this.post.last_wiki_edit.getTime().toString(10),
        "the relative date is based in the last time the wiki was edited"
      );

    await click(".post-info .wiki");
    assert.verifySteps(
      ["show history called"],
      "clicking the wiki icon displays the post history"
    );
  });

  test("wiki without revision", async function (assert) {
    this.post.wiki = true;
    this.post.version = 1;
    this.post.can_view_edit_history = true;

    await renderComponent(this.post, {
      editPost: () => assert.step("edit post called"),
    });

    await click(".post-info .wiki");
    assert.verifySteps(
      ["edit post called"],
      "clicking wiki icon edits the post"
    );
  });

  test("via-email", async function (assert) {
    this.currentUser.can_view_raw_email = true;
    this.post.via_email = true;

    await renderComponent(this.post, {
      showRawEmail: () => assert.step("show raw email called"),
    });

    await click(".post-info.via-email");
    assert.verifySteps(
      ["show raw email called"],
      "clicking the envelope shows the raw email"
    );
  });

  test("via-email without permission", async function (assert) {
    this.currentUser.can_view_raw_email = false;
    this.post.via_email = true;

    await renderComponent(this.post, {
      showRawEmail: () => assert.step("show raw email called"),
    });

    await click(".post-info.via-email");
    assert.verifySteps([], "clicking the envelope doesn't show the raw email");
  });

  test("history", async function (assert) {
    this.post.version = 3;
    this.post.can_view_edit_history = true;

    await renderComponent(this.post, {
      showHistory: () => assert.step("show history called"),
    });

    await click(".post-info.edits button");
    assert.verifySteps(
      ["show history called"],
      "clicking the pencil shows the history"
    );
  });

  test("history without view permission", async function (assert) {
    this.post.version = 3;
    this.post.can_view_edit_history = false;

    await renderComponent(this.post, {
      showHistory: () => assert.step("show history called"),
    });

    await click(".post-info.edits button");
    assert.verifySteps([], "clicking the pencil doesn't show the history");
  });

  test("whisper", async function (assert) {
    this.post.post_type = this.site.post_types.whisper;

    await renderComponent(this.post);

    assert.strictEqual(count(".topic-post.whisper"), 1);
    assert.strictEqual(count(".post-info.whisper"), 1);
  });

  test("language", async function (assert) {
    this.post.is_localized = true;
    this.post.language = "English";

    await renderComponent(this.post);

    await triggerEvent(".fk-d-tooltip__trigger", "pointermove");
    assert.dom(".post-language").hasText(
      i18n("post.original_language", {
        language: "English",
      })
    );
  });

  test("outdated localization", async function (assert) {
    this.post.is_localized = true;
    this.post.language = "English";
    this.post.localization_outdated = true;

    await renderComponent(this.post);

    await triggerEvent(".fk-d-tooltip__trigger", "pointermove");
    assert.dom(".post-language").hasText(
      i18n("post.original_language_and_outdated", {
        language: "English",
      })
    );
  });

  test("read indicator", async function (assert) {
    this.post.read = true;

    await renderComponent(this.post);

    assert.dom(".read-state.read").exists();
  });

  test("unread indicator", async function (assert) {
    this.post.read = false;

    await renderComponent(this.post);

    assert.dom(".read-state").exists();
  });

  test("reply directly above (suppressed)", async function (assert) {
    this.post.reply_to_user = {
      username: "eviltrout",
      avatar_template: "/images/avatar.png",
    };
    this.post.post_number = 2;
    this.post.reply_to_post_number = 1;

    const prevPost = this.store.createRecord("post", {
      id: 122,
      post_number: 1,
      topic: this.post.topic,
    });

    await renderComponent(this.post, { prevPost });

    assert.dom("a.reply-to-tab").doesNotExist("hides the tab");
    assert.dom(".avoid-tab").doesNotExist("doesn't have the avoid tab class");
  });

  test("reply a few posts above", async function (assert) {
    this.post.reply_to_user = {
      username: "eviltrout",
      avatar_template: "/images/avatar.png",
    };
    this.post.post_number = 5;
    this.post.reply_to_post_number = 1;

    const prevPost = this.store.createRecord("post", {
      id: 122,
      post_number: 4,
      topic: this.post.topic,
    });

    await renderComponent(this.post, { prevPost });

    assert.dom("a.reply-to-tab").exists("shows the tab");
    assert.strictEqual(count(".avoid-tab"), 1, "has the avoid tab class");
  });

  test("reply directly above", async function (assert) {
    this.siteSettings.suppress_reply_directly_above = false;
    this.post.reply_to_user = {
      username: "eviltrout",
      avatar_template: "/images/avatar.png",
    };
    this.post.post_number = 2;
    this.post.reply_to_post_number = 1;

    const prevPost = this.store.createRecord("post", {
      id: 122,
      post_number: 1,
      topic: this.post.topic,
    });

    await renderComponent(this.post, { prevPost });

    assert.strictEqual(count(".avoid-tab"), 1, "has the avoid tab class");
    await click("a.reply-to-tab");
    assert.strictEqual(count("section.embedded-posts.top .cooked"), 1);
    assert.strictEqual(count("section.embedded-posts .d-icon-arrow-up"), 1);
  });

  test("cooked content hidden", async function (assert) {
    this.post.cooked_hidden = true;
    this.post.can_see_hidden_post = true;

    await renderComponent(this.post, {
      expandHidden: () => assert.step("expand hidden called"),
    });

    await click(".topic-body .expand-hidden");
    assert.verifySteps(["expand hidden called"], "expand the cooked content");
  });

  test(`cooked content hidden - can't view hidden post`, async function (assert) {
    this.post.cooked_hidden = true;
    this.post.can_see_hidden_post = false;

    await renderComponent(this.post);

    assert
      .dom(".topic-body .expand-hidden")
      .doesNotExist("button is not displayed");
  });

  test("expand first post", async function (assert) {
    this.post.post_number = 1;
    this.post.topic.expandable_first_post = true;

    await renderComponent(this.post);

    await click(".topic-body .expand-post");
    assert.dom(".expand-post").doesNotExist("button is gone");
  });

  test("can't show admin menu when you can't manage", async function (assert) {
    this.currentUser.admin = false;

    await renderComponent(this.post);

    assert.dom(".post-menu-area .show-post-admin-menu").doesNotExist();
  });

  test("show admin menu", async function (assert) {
    this.currentUser.admin = true;

    await renderComponent(this.post);

    assert
      .dom("[data-content][data-identifier='admin-post-menu']")
      .doesNotExist();

    await click(".post-menu-area .show-post-admin-menu");
    assert.dom("[data-content][data-identifier='admin-post-menu']").exists();

    await triggerEvent(".post-menu-area", "pointerdown");
    assert
      .dom("[data-content][data-identifier='admin-post-menu']")
      .doesNotExist("clicking outside clears the popup");
  });

  test("permanently delete topic", async function (assert) {
    this.currentUser.admin = true;

    this.post.topic.details.can_permanently_delete = true;
    this.post.deleted_at = new Date().toISOString();

    await renderComponent(this.post, {
      permanentlyDeletePost: () =>
        assert.step("permanently delete post called"),
    });

    await click(".post-menu-area .show-post-admin-menu");
    await click(
      "[data-content][data-identifier='admin-post-menu'] .permanently-delete"
    );
    assert.verifySteps(
      ["permanently delete post called"],
      "clicked on permanently delete"
    );
    assert
      .dom("[data-content][data-identifier='admin-post-menu']")
      .doesNotExist("also hides the menu");
  });

  test("permanently delete post", async function (assert) {
    this.currentUser.admin = true;

    this.post.post_number = 2;
    this.post.can_permanently_delete = true;
    this.post.deleted_at = new Date().toISOString();

    await renderComponent(this.post, {
      permanentlyDeletePost: () =>
        assert.step("permanently delete post called"),
    });

    await click(".post-menu-area .show-post-admin-menu");

    await click(
      "[data-content][data-identifier='admin-post-menu'] .permanently-delete"
    );
    assert.verifySteps(
      ["permanently delete post called"],
      "clicked on permanently delete"
    );
    assert
      .dom("[data-content][data-identifier='admin-post-menu']")
      .doesNotExist("also hides the menu");
  });

  test("toggle moderator post", async function (assert) {
    this.currentUser.moderator = true;

    await renderComponent(this.post, {
      togglePostType: () => assert.step("toggle post type called"),
    });

    await click(".post-menu-area .show-post-admin-menu");
    await click(
      "[data-content][data-identifier='admin-post-menu'] .toggle-post-type"
    );
    assert.verifySteps(
      ["toggle post type called"],
      "clicked on toggle moderator post (add staff color)"
    );
    assert
      .dom("[data-content][data-identifier='admin-post-menu']")
      .doesNotExist("also hides the menu");
  });

  test("rebake post", async function (assert) {
    this.currentUser.moderator = true;

    await renderComponent(this.post, {
      rebakePost: () => assert.step("rebake post called"),
    });

    await click(".post-menu-area .show-post-admin-menu");
    await click(
      "[data-content][data-identifier='admin-post-menu'] .rebuild-html"
    );
    assert.verifySteps(
      ["rebake post called"],
      "clicked on rebake post (rebuild html)"
    );
    assert
      .dom("[data-content][data-identifier='admin-post-menu']")
      .doesNotExist("also hides the menu");
  });

  test("unhide post", async function (assert) {
    this.currentUser.admin = true;
    this.post.hidden = true;

    await renderComponent(this.post, {
      unhidePost: () => assert.step("unhide post called"),
    });

    await click(".post-menu-area .show-post-admin-menu");

    await click(
      "[data-content][data-identifier='admin-post-menu'] .unhide-post"
    );
    assert.verifySteps(["unhide post called"], "clicked on unhide post");
    assert
      .dom("[data-content][data-identifier='admin-post-menu']")
      .doesNotExist("also hides the menu");
  });

  test("change owner", async function (assert) {
    this.currentUser.admin = true;

    await renderComponent(this.post, {
      changePostOwner: () => assert.step("change post owner called"),
    });

    await click(".post-menu-area .show-post-admin-menu");
    await click(
      "[data-content][data-identifier='admin-post-menu'] .change-owner"
    );
    assert.verifySteps(
      ["change post owner called"],
      "clicked on change post owner"
    );
    assert
      .dom("[data-content][data-identifier='admin-post-menu']")
      .doesNotExist("also hides the menu");
  });

  test("the topic map visibility can be changed using the `post-show-topic-map` transformer", async function (assert) {
    this.siteSettings.show_topic_map_in_topics_without_replies = false;

    this.post.post_number = 1;

    await renderComponent(this.post);
    assert.dom(".topic-map").doesNotExist();

    withPluginApi((api) => {
      api.registerValueTransformer("post-show-topic-map", () => true);
    });

    await renderComponent(this.post);

    assert.dom(".topic-map").exists();
  });

  test("shows the topic map when there are no replies", async function (assert) {
    this.siteSettings.show_topic_map_in_topics_without_replies = true;

    this.post.topic.archetype = "regular";
    this.post.post_number = 1;

    await renderComponent(this.post);

    assert.dom(".topic-map").exists();
  });

  test("topic map - few participants", async function (assert) {
    this.post.topic.posts_count = 10;
    this.post.topic.participant_count = 2;
    this.post.topic.archetype = "regular";
    this.post.topic.details.set("participants", [
      { username: "eviltrout" },
      { username: "codinghorror" },
    ]);
    this.post.post_number = 1;

    await renderComponent(this.post);

    assert.dom(".topic-map__users-trigger").doesNotExist();
    assert.dom(".topic-map__users-list a.poster").exists({ count: 2 });
  });

  test("topic map - participants", async function (assert) {
    this.post.topic.posts_count = 10;
    this.post.topic.participant_count = 6;
    this.post.topic.archetype = "regular";
    this.post.topic.postStream.setProperties({
      userFilters: ["sam", "codinghorror"],
    });
    this.post.topic.details.set("participants", [
      { username: "eviltrout" },
      { username: "codinghorror" },
      { username: "sam" },
      { username: "zogstrip" },
      { username: "joffreyjaffeux" },
      { username: "david" },
    ]);
    this.post.post_number = 1;

    await renderComponent(this.post);

    assert.dom(".topic-map__users-list a.poster").exists({ count: 5 });

    await click(".topic-map__users-trigger");
    assert
      .dom(".topic-map__users-content .topic-map__users-list a.poster")
      .exists({ count: 6 });
  });

  test("topic map - no top reply summary", async function (assert) {
    this.post.topic.posts_count = 2;
    this.post.topic.archetype = "regular";
    this.post.post_number = 1;

    await renderComponent(this.post);

    assert.dom(".topic-map").exists();
    assert.dom(".summarization-button .top-replies").doesNotExist();
  });

  test("topic map - has top replies summary", async function (assert) {
    this.post.topic.posts_count = 2;
    this.post.topic.archetype = "regular";
    this.post.topic.has_summary = true;
    this.post.post_number = 1;

    await renderComponent(this.post);

    assert.dom(".summarization-button .top-replies").exists({ count: 1 });
  });

  test("pm map", async function (assert) {
    this.post.topic.posts_count = 2;
    this.post.topic.archetype = "private_message";
    this.post.topic.details.allowed_users = [{ username: "eviltrout" }];
    this.post.post_number = 1;

    await renderComponent(this.post);

    assert.dom(".topic-map__private-message-map").exists({ count: 1 });
    assert.dom(".topic-map__private-message-map .user").exists({ count: 1 });
  });

  test("post notice - with username", async function (assert) {
    const twoDaysAgo = new Date();
    twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);
    this.siteSettings.display_name_on_posts = false;
    this.siteSettings.prioritize_username_in_ux = true;
    this.siteSettings.old_post_notice_days = 14;

    this.post.username = "codinghorror";
    this.post.name = "Jeff";
    this.post.created_at = new Date();
    this.post.notice = {
      type: "returning_user",
      last_posted_at: twoDaysAgo,
    };

    await renderComponent(this.post);

    assert.dom(".post-notice.returning-user:not(.old)").hasText(
      i18n("post.notice.returning_user", {
        user: "codinghorror",
        time: "2 days ago",
      })
    );
  });

  test("post notice - with name", async function (assert) {
    this.siteSettings.display_name_on_posts = true;
    this.siteSettings.prioritize_username_in_ux = false;
    this.siteSettings.old_post_notice_days = 14;

    this.post.username = "codinghorror";
    this.post.name = "Jeff";
    this.post.created_at = new Date(2019, 0, 1);
    this.post.notice = { type: "new_user" };

    await renderComponent(this.post);

    assert
      .dom(".post-notice.old.new-user")
      .hasText(i18n("post.notice.new_user", { user: "Jeff", time: "Jan '10" }));
  });

  test("show group request in post", async function (assert) {
    this.post.username = "foo";
    this.post.topic.requested_group_name = "testGroup";
    this.post.post_number = 1;

    await renderComponent(this.post);

    assert.dom(".group-request a").hasText(i18n("groups.requests.handle"));
    assert
      .dom(".group-request a")
      .hasAttribute("href", "/g/testGroup/requests?filter=foo");
  });

  test("shows user status if enabled in site settings", async function (assert) {
    this.siteSettings.enable_user_status = true;
    const status = {
      emoji: "tooth",
      description: "off to dentist",
    };

    this.post.user = this.store.createRecord("user", { status });

    await renderComponent(this.post);

    assert.dom(".user-status-message").exists();
  });

  test("doesn't show user status if disabled in site settings", async function (assert) {
    this.siteSettings.enable_user_status = false;
    const status = {
      emoji: "tooth",
      description: "off to dentist",
    };

    this.post.user = this.store.createRecord("user", { status });

    await renderComponent(this.post);

    assert.dom(".user-status-message").doesNotExist();
  });

  test("more actions button is displayed when multiple hidden items are configured", async function (assert) {
    this.siteSettings.post_menu_hidden_items = "bookmark|edit|copyLink";

    await renderComponent(this.post);
    assert.dom(".show-more-actions").exists();
  });

  test("hidden menu expands automatically when only one hidden item is configured", async function (assert) {
    this.siteSettings.post_menu_hidden_items = "bookmark";

    await renderComponent(this.post);

    assert.dom(".show-more-actions").doesNotExist();
  });
});
