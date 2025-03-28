import EmberObject from "@ember/object";
import { getOwner } from "@ember/owner";
import { click, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import MountWidget from "discourse/components/mount-widget";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import DMenus from "float-kit/components/d-menus";

// TODO (glimmer-post-stream) remove this test when removing the widget post stream code
module("Integration | Component | Widget | post", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.post_menu_hidden_items = "";

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 123 });
    const post = store.createRecord("post", {
      id: 1,
      post_number: 1,
      topic,
      like_count: 3,
      actions_summary: [{ id: 2, count: 1, hidden: false, can_act: true }],
    });

    this.set("post", post);
    this.set("args", {});
  });

  test("basic elements", async function (assert) {
    const self = this;

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 123,
      archetype: "regular",
    });

    this.set("args", { shareUrl: "/example", post_number: 1, topic });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".names").exists("includes poster name");
    assert.dom("a.post-date").exists("includes post date");
  });

  test("post - links", async function (assert) {
    const self = this;

    this.set("args", {
      cooked:
        "<a href='http://link1.example.com/'>first link</a> and <a href='http://link2.example.com/?some=query'>second link</a>",
      linkCounts: [
        { url: "http://link1.example.com/", clicks: 1, internal: true },
        { url: "http://link2.example.com/", clicks: 2, internal: true },
      ],
    });

    await render(
      <template>
        <MountWidget
          @widget="post-contents"
          @model={{self.post}}
          @args={{self.args}}
        />
      </template>
    );

    assert.dom("a[data-clicks='1']").hasAttribute("data-clicks", "1");
    assert.dom("a[data-clicks='2']").hasAttribute("data-clicks", "2");
  });

  test("post - onebox links", async function (assert) {
    const self = this;

    this.set("args", {
      cooked: `
      <p><a href="https://example.com">Other URL</a></p>

      <aside class="onebox twitterstatus" data-onebox-src="https://twitter.com/codinghorror">
        <header class="source">
           <a href="https://twitter.com/codinghorror" target="_blank" rel="noopener">twitter.com</a>
        </header>
        <article class="onebox-body">
           <h4><a href="https://twitter.com/codinghorror" target="_blank" rel="noopener">Jeff Atwood</a></h4>
           <div class="twitter-screen-name"><a href="https://twitter.com/codinghorror" target="_blank" rel="noopener">@codinghorror</a></div>
        </article>
      </aside>`,
      linkCounts: [
        { url: "https://example.com", clicks: 1 },
        { url: "https://twitter.com/codinghorror", clicks: 2 },
      ],
    });

    await render(
      <template>
        <MountWidget
          @widget="post-contents"
          @model={{self.post}}
          @args={{self.args}}
        />
      </template>
    );

    assert
      .dom("a[data-clicks='1']")
      .hasAttribute(
        "data-clicks",
        "1",
        "First link has correct data attribute and content"
      );
    assert
      .dom("a[data-clicks='2']")
      .hasAttribute(
        "data-clicks",
        "2",
        "Second link has correct data attribute and content"
      );
  });

  test("wiki", async function (assert) {
    const self = this;

    this.set("args", { wiki: true, version: 2, canViewEditHistory: true });
    this.set("showHistory", () => (this.historyShown = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @model={{self.post}}
          @args={{self.args}}
          @showHistory={{self.showHistory}}
        />
      </template>
    );

    await click(".post-info .wiki");
    assert.true(
      this.historyShown,
      "clicking the wiki icon displays the post history"
    );
  });

  test("wiki without revision", async function (assert) {
    const self = this;

    this.set("args", { wiki: true, version: 1, canViewEditHistory: true });
    this.set("editPost", () => (this.editPostCalled = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @model={{self.post}}
          @args={{self.args}}
          @editPost={{self.editPost}}
        />
      </template>
    );

    await click(".post-info .wiki");
    assert.true(this.editPostCalled, "clicking wiki icon edits the post");
  });

  test("via-email", async function (assert) {
    const self = this;

    this.set("args", { via_email: true, canViewRawEmail: true });
    this.set("showRawEmail", () => (this.rawEmailShown = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @model={{self.post}}
          @args={{self.args}}
          @showRawEmail={{self.showRawEmail}}
        />
      </template>
    );

    await click(".post-info.via-email");
    assert.true(
      this.rawEmailShown,
      "clicking the envelope shows the raw email"
    );
  });

  test("via-email without permission", async function (assert) {
    const self = this;

    this.rawEmailShown = false;
    this.set("args", { via_email: true, canViewRawEmail: false });
    this.set("showRawEmail", () => (this.rawEmailShown = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @model={{self.post}}
          @args={{self.args}}
          @showRawEmail={{self.showRawEmail}}
        />
      </template>
    );

    await click(".post-info.via-email");
    assert.false(
      this.rawEmailShown,
      "clicking the envelope doesn't show the raw email"
    );
  });

  test("history", async function (assert) {
    const self = this;

    this.set("args", { version: 3, canViewEditHistory: true });
    this.set("showHistory", () => (this.historyShown = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @model={{self.post}}
          @args={{self.args}}
          @showHistory={{self.showHistory}}
        />
      </template>
    );

    await click(".post-info.edits button");
    assert.true(this.historyShown, "clicking the pencil shows the history");
  });

  test("history without view permission", async function (assert) {
    const self = this;

    this.historyShown = false;
    this.set("args", { version: 3, canViewEditHistory: false });
    this.set("showHistory", () => (this.historyShown = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @model={{self.post}}
          @args={{self.args}}
          @showHistory={{self.showHistory}}
        />
      </template>
    );

    await click(".post-info.edits");
    assert.false(
      this.historyShown,
      `clicking the pencil doesn't show the history`
    );
  });

  test("whisper", async function (assert) {
    const self = this;

    this.set("args", { isWhisper: true });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".topic-post.whisper").exists();
    assert.dom(".post-info.whisper").exists();
  });

  test(`read indicator`, async function (assert) {
    const self = this;

    this.set("args", { read: true });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".read-state.read").exists();
  });

  test(`unread indicator`, async function (assert) {
    const self = this;

    this.set("args", { read: false });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".read-state").exists();
  });

  test("reply directly above (suppressed)", async function (assert) {
    const self = this;

    this.set("args", {
      replyToUsername: "eviltrout",
      replyToAvatarTemplate: "/images/avatar.png",
      replyDirectlyAbove: true,
    });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom("a.reply-to-tab").doesNotExist("hides the tab");
    assert.dom(".avoid-tab").doesNotExist("doesn't have the avoid tab class");
  });

  test("reply a few posts above (suppressed)", async function (assert) {
    const self = this;

    this.set("args", {
      replyToUsername: "eviltrout",
      replyToAvatarTemplate: "/images/avatar.png",
      replyDirectlyAbove: false,
    });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom("a.reply-to-tab").exists("shows the tab");
    assert.dom(".avoid-tab").exists("has the avoid tab class");
  });

  test("reply directly above", async function (assert) {
    const self = this;

    this.set("args", {
      replyToUsername: "eviltrout",
      replyToAvatarTemplate: "/images/avatar.png",
      replyDirectlyAbove: true,
    });
    this.siteSettings.suppress_reply_directly_above = false;

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".avoid-tab").exists("has the avoid tab class");
    await click("a.reply-to-tab");
    assert.dom("section.embedded-posts.top .cooked").exists();
    assert.dom("section.embedded-posts .d-icon-arrow-up").exists();
  });

  test("cooked content hidden", async function (assert) {
    const self = this;

    this.set("args", { cooked_hidden: true, canSeeHiddenPost: true });
    this.set("expandHidden", () => (this.unhidden = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @model={{self.post}}
          @args={{self.args}}
          @expandHidden={{self.expandHidden}}
        />
      </template>
    );

    await click(".topic-body .expand-hidden");
    assert.true(this.unhidden, "triggers the action");
  });

  test(`cooked content hidden - can't view hidden post`, async function (assert) {
    const self = this;

    this.set("args", { cooked_hidden: true, canSeeHiddenPost: false });
    this.set("expandHidden", () => (this.unhidden = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @model={{self.post}}
          @args={{self.args}}
          @expandHidden={{self.expandHidden}}
        />
      </template>
    );

    assert
      .dom(".topic-body .expand-hidden")
      .doesNotExist("button is not displayed");
  });

  test("expand first post", async function (assert) {
    const self = this;

    this.set("args", { expandablePost: true });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    await click(".topic-body .expand-post");
    assert.dom(".expand-post").doesNotExist("button is gone");
  });

  test("can't show admin menu when you can't manage", async function (assert) {
    const self = this;

    this.set("args", { canManage: false });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".post-menu-area .show-post-admin-menu").doesNotExist();
  });

  test("show admin menu", async function (assert) {
    const self = this;

    this.currentUser.admin = true;

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
        <DMenus />
      </template>
    );

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
    const self = this;

    this.currentUser.set("admin", true);
    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 123,
      details: { can_permanently_delete: true },
    });
    const post = store.createRecord("post", {
      id: 1,
      post_number: 1,
      deleted_at: new Date().toISOString(),
      topic,
    });

    this.set("args", { canManage: true });
    this.set("post", post);
    this.set("permanentlyDeletePost", () => (this.deleted = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @model={{self.post}}
          @args={{self.args}}
          @permanentlyDeletePost={{self.permanentlyDeletePost}}
        />
        <DMenus />
      </template>
    );

    await click(".post-menu-area .show-post-admin-menu");
    await click(
      "[data-content][data-identifier='admin-post-menu'] .permanently-delete"
    );
    assert.true(this.deleted);
    assert
      .dom("[data-content][data-identifier='admin-post-menu']")
      .doesNotExist("also hides the menu");
  });

  test("permanently delete post", async function (assert) {
    const self = this;

    this.currentUser.set("admin", true);
    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 123,
    });
    const post = store.createRecord("post", {
      id: 1,
      post_number: 2,
      deleted_at: new Date().toISOString(),
      can_permanently_delete: true,
      topic,
    });

    this.set("args", { canManage: true });
    this.set("post", post);
    this.set("permanentlyDeletePost", () => (this.deleted = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @model={{self.post}}
          @args={{self.args}}
          @permanentlyDeletePost={{self.permanentlyDeletePost}}
        />
        <DMenus />
      </template>
    );

    await click(".post-menu-area .show-post-admin-menu");

    await click(
      "[data-content][data-identifier='admin-post-menu'] .permanently-delete"
    );
    assert.true(this.deleted);
    assert
      .dom("[data-content][data-identifier='admin-post-menu']")
      .doesNotExist("also hides the menu");
  });

  test("toggle moderator post", async function (assert) {
    const self = this;

    this.currentUser.set("moderator", true);

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 123,
    });
    const post = store.createRecord("post", {
      id: 1,
      post_number: 2,
      deleted_at: new Date().toISOString(),
      can_permanently_delete: true,
      topic,
    });

    this.set("args", { canManage: true });
    this.set("post", post);
    this.set("togglePostType", () => (this.toggled = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @model={{self.post}}
          @args={{self.args}}
          @togglePostType={{self.togglePostType}}
        />
        <DMenus />
      </template>
    );

    await click(".post-menu-area .show-post-admin-menu");
    await click(
      "[data-content][data-identifier='admin-post-menu'] .toggle-post-type"
    );

    assert.true(this.toggled);
    assert
      .dom("[data-content][data-identifier='admin-post-menu']")
      .doesNotExist("also hides the menu");
  });

  test("rebake post", async function (assert) {
    const self = this;

    this.currentUser.moderator = true;
    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 123 });
    const post = store.createRecord("post", {
      id: 1,
      post_number: 1,
      topic,
    });

    this.set("args", { canManage: true });
    this.set("post", post);
    this.set("rebakePost", () => (this.baked = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @model={{self.post}}
          @args={{self.args}}
          @rebakePost={{self.rebakePost}}
        />
        <DMenus />
      </template>
    );

    await click(".post-menu-area .show-post-admin-menu");
    await click(
      "[data-content][data-identifier='admin-post-menu'] .rebuild-html"
    );
    assert.true(this.baked);
    assert
      .dom("[data-content][data-identifier='admin-post-menu']")
      .doesNotExist("also hides the menu");
  });

  test("unhide post", async function (assert) {
    const self = this;

    let unhidden;

    this.currentUser.admin = true;
    this.post.hidden = true;
    this.set("args", { canManage: true });
    this.set("unhidePost", () => (unhidden = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @model={{self.post}}
          @args={{self.args}}
          @unhidePost={{self.unhidePost}}
        />
        <DMenus />
      </template>
    );

    await click(".post-menu-area .show-post-admin-menu");

    await click(
      "[data-content][data-identifier='admin-post-menu'] .unhide-post"
    );

    assert.true(unhidden);

    assert
      .dom("[data-content][data-identifier='admin-post-menu']")
      .doesNotExist("also hides the menu");
  });

  test("change owner", async function (assert) {
    const self = this;

    this.currentUser.admin = true;
    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 123 });
    const post = store.createRecord("post", {
      id: 1,
      post_number: 1,
      hidden: true,
      topic,
    });

    this.set("args", { canManage: true });
    this.set("post", post);
    this.set("changePostOwner", () => (this.owned = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @model={{self.post}}
          @args={{self.args}}
          @changePostOwner={{self.changePostOwner}}
        />
        <DMenus />
      </template>
    );

    await click(".post-menu-area .show-post-admin-menu");
    await click(
      "[data-content][data-identifier='admin-post-menu'] .change-owner"
    );
    assert.true(this.owned);
    assert
      .dom("[data-content][data-identifier='admin-post-menu']")
      .doesNotExist("also hides the menu");
  });

  test("shows the topic map when setting the 'topicMap' attribute", async function (assert) {
    const self = this;

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 123 });
    this.set("args", { topic, post_number: 1, topicMap: true });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".topic-map").exists();
  });

  test("shows the topic map when no replies", async function (assert) {
    const self = this;

    this.siteSettings.show_topic_map_in_topics_without_replies = true;

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 123,
      archetype: "regular",
    });
    this.set("args", { topic, post_number: 1 });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".topic-map").exists();
  });

  test("topic map - few participants", async function (assert) {
    const self = this;

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 123,
      posts_count: 10,
      participant_count: 2,
      archetype: "regular",
    });
    topic.details.set("participants", [
      { username: "eviltrout" },
      { username: "codinghorror" },
    ]);
    this.set("args", {
      topic,
      post_number: 1,
    });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );
    assert.dom(".topic-map__users-trigger").doesNotExist();
    assert.dom(".topic-map__users-list a.poster").exists({ count: 2 });
  });

  test("topic map - participants", async function (assert) {
    const self = this;

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 123,
      posts_count: 10,
      participant_count: 6,
      archetype: "regular",
    });
    topic.postStream.setProperties({ userFilters: ["sam", "codinghorror"] });
    topic.details.set("participants", [
      { username: "eviltrout" },
      { username: "codinghorror" },
      { username: "sam" },
      { username: "zogstrip" },
      { username: "joffreyjaffeux" },
      { username: "david" },
    ]);

    this.set("args", {
      topic,
      post_number: 1,
    });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );
    assert.dom(".topic-map__users-list a.poster").exists({ count: 5 });

    await click(".topic-map__users-trigger");
    assert
      .dom(".topic-map__users-content .topic-map__users-list a.poster")
      .exists({ count: 6 });
  });

  test("topic map - links", async function (assert) {
    const self = this;

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 123,
      posts_count: 2,
      archetype: "regular",
    });
    topic.details.set("links", [
      { url: "http://link1.example.com", clicks: 0 },
      { url: "http://link2.example.com", clicks: 0 },
      { url: "http://link3.example.com", clicks: 0 },
      { url: "http://link4.example.com", clicks: 0 },
      { url: "http://link5.example.com", clicks: 0 },
      { url: "http://link6.example.com", clicks: 0 },
    ]);
    this.set("args", { topic, post_number: 1 });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".topic-map").exists({ count: 1 });
    assert.dom(".topic-map__links-content").doesNotExist();
    await click(".topic-map__links-trigger");
    assert.dom(".topic-map__links-content").exists({ count: 1 });
    assert.dom(".topic-map__links-content .topic-link").exists({ count: 5 });
    await click(".link-summary");
    assert.dom(".topic-map__links-content .topic-link").exists({ count: 6 });
  });

  test("topic map - has top replies summary", async function (assert) {
    const self = this;

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 123,
      archetype: "regular",
      posts_count: 2,
      has_summary: true,
    });
    this.set("args", { topic, post_number: 1 });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".summarization-button .top-replies").exists({ count: 1 });
  });

  test("topic map - no top reply summary", async function (assert) {
    const self = this;

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 123,
      archetype: "regular",
      posts_count: 2,
    });
    this.set("args", { topic, post_number: 1 });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".topic-map").exists();
    assert.dom(".summarization-button .top-replies").doesNotExist();
  });

  test("pm map", async function (assert) {
    const self = this;

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 123,
      archetype: "private_message",
    });
    topic.details.set("allowed_users", [
      EmberObject.create({ username: "eviltrout" }),
    ]);
    this.set("args", {
      topic,
      post_number: 1,
    });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".topic-map__private-message-map").exists({ count: 1 });
    assert.dom(".topic-map__private-message-map .user").exists({ count: 1 });
  });

  test("post notice - with username", async function (assert) {
    const self = this;

    const twoDaysAgo = new Date();
    twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);
    this.siteSettings.display_name_on_posts = false;
    this.siteSettings.prioritize_username_in_ux = true;
    this.siteSettings.old_post_notice_days = 14;
    this.set("args", {
      username: "codinghorror",
      name: "Jeff",
      created_at: new Date(),
      notice: {
        type: "returning_user",
        lastPostedAt: twoDaysAgo,
      },
    });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".post-notice.returning-user:not(.old)").hasText(
      i18n("post.notice.returning_user", {
        user: "codinghorror",
        time: "2 days ago",
      })
    );
  });

  test("post notice - custom official notice with created by username", async function (assert) {
    const self = this;

    this.siteSettings.display_name_on_posts = false;
    this.siteSettings.prioritize_username_in_ux = true;
    this.set("args", {
      notice: {
        type: "custom",
        cooked: "<p>This is an official notice</p>",
      },
      noticeCreatedByUser: {
        username: "codinghorror",
        name: "Jeff",
        id: 1,
      },
    });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".post-notice.custom").hasText(
      "This is an official notice " +
        i18n("post.notice.custom_created_by", {
          userLinkHTML: "codinghorror",
        })
    );

    assert
      .dom(
        ".post-notice.custom .post-notice-message a.trigger-user-card[data-user-card='codinghorror']"
      )
      .exists();
  });

  test("post notice - with name", async function (assert) {
    const self = this;

    this.siteSettings.display_name_on_posts = true;
    this.siteSettings.prioritize_username_in_ux = false;
    this.siteSettings.old_post_notice_days = 14;
    this.set("args", {
      username: "codinghorror",
      name: "Jeff",
      created_at: new Date(2019, 0, 1),
      notice: { type: "new_user" },
    });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert
      .dom(".post-notice.old.new-user")
      .hasText(i18n("post.notice.new_user", { user: "Jeff", time: "Jan '10" }));
  });

  test("show group request in post", async function (assert) {
    const self = this;

    this.set("args", {
      username: "foo",
      requestedGroupName: "testGroup",
    });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".group-request a").hasText(i18n("groups.requests.handle"));
    assert
      .dom(".group-request a")
      .hasAttribute("href", "/g/testGroup/requests?filter=foo");
  });

  test("shows user status if enabled in site settings", async function (assert) {
    const self = this;

    this.siteSettings.enable_user_status = true;
    const status = {
      emoji: "tooth",
      description: "off to dentist",
    };
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user", { status });
    this.set("args", { user });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".user-status-message").exists();
  });

  test("doesn't show user status if disabled in site settings", async function (assert) {
    const self = this;

    this.siteSettings.enable_user_status = false;
    const status = {
      emoji: "tooth",
      description: "off to dentist",
    };
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user", { status });
    this.set("args", { user });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom(".user-status-message").doesNotExist();
  });

  test("more actions button is displayed when multiple hidden items are configured", async function (assert) {
    const self = this;

    this.siteSettings.post_menu_hidden_items = "bookmark|edit|copyLink";

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );
    assert.dom(".show-more-actions").exists();
  });

  test("hidden menu expands automatically when only one hidden item is configured", async function (assert) {
    const self = this;

    this.siteSettings.post_menu_hidden_items = "bookmark|edit";

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );
    assert.dom(".show-more-actions").doesNotExist();
  });
});
