import EmberObject from "@ember/object";
import { getOwner } from "@ember/owner";
import { click, render, triggerEvent } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  count,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

module(
  "Integration | Component | Widget | post with glimmer-post-menu",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.glimmer_post_menu_mode = "enabled";
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
      const store = getOwner(this).lookup("service:store");
      const topic = store.createRecord("topic", {
        id: 123,
        archetype: "regular",
      });

      this.set("args", { shareUrl: "/example", post_number: 1, topic });

      await render(hbs`
      <MountWidget @widget="post"
                   @model={{this.post}}
                   @args={{this.args}} />`);

      assert.ok(exists(".names"), "includes poster name");
      assert.ok(exists("a.post-date"), "includes post date");
    });

    test("post - links", async function (assert) {
      this.set("args", {
        cooked:
          "<a href='http://link1.example.com/'>first link</a> and <a href='http://link2.example.com/?some=query'>second link</a>",
        linkCounts: [
          { url: "http://link1.example.com/", clicks: 1, internal: true },
          { url: "http://link2.example.com/", clicks: 2, internal: true },
        ],
      });

      await render(
        hbs`
        <MountWidget @widget="post-contents" @model={{this.post}} @args={{this.args}} />`
      );

      assert.strictEqual(queryAll(".badge.clicks")[0].innerText, "1");
      assert.strictEqual(queryAll(".badge.clicks")[1].innerText, "2");
    });

    test("post - onebox links", async function (assert) {
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
        hbs`
        <MountWidget @widget="post-contents" @model={{this.post}} @args={{this.args}} />`
      );

      assert.strictEqual(count(".badge.clicks"), 2);
      assert.strictEqual(queryAll(".badge.clicks")[0].innerText, "1");
      assert.strictEqual(queryAll(".badge.clicks")[1].innerText, "2");
    });

    test("wiki", async function (assert) {
      this.set("args", { wiki: true, version: 2, canViewEditHistory: true });
      this.set("showHistory", () => (this.historyShown = true));

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}}
                   @showHistory={{this.showHistory}} />
    `);

      await click(".post-info .wiki");
      assert.ok(
        this.historyShown,
        "clicking the wiki icon displays the post history"
      );
    });

    test("wiki without revision", async function (assert) {
      this.set("args", { wiki: true, version: 1, canViewEditHistory: true });
      this.set("editPost", () => (this.editPostCalled = true));

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}}
                   @editPost={{this.editPost}} />
    `);

      await click(".post-info .wiki");
      assert.ok(this.editPostCalled, "clicking wiki icon edits the post");
    });

    test("via-email", async function (assert) {
      this.set("args", { via_email: true, canViewRawEmail: true });
      this.set("showRawEmail", () => (this.rawEmailShown = true));

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} @showRawEmail={{this.showRawEmail}} />`
      );

      await click(".post-info.via-email");
      assert.ok(
        this.rawEmailShown,
        "clicking the envelope shows the raw email"
      );
    });

    test("via-email without permission", async function (assert) {
      this.set("args", { via_email: true, canViewRawEmail: false });
      this.set("showRawEmail", () => (this.rawEmailShown = true));

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} @showRawEmail={{this.showRawEmail}} />`
      );

      await click(".post-info.via-email");
      assert.ok(
        !this.rawEmailShown,
        "clicking the envelope doesn't show the raw email"
      );
    });

    test("history", async function (assert) {
      this.set("args", { version: 3, canViewEditHistory: true });
      this.set("showHistory", () => (this.historyShown = true));

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} @showHistory={{this.showHistory}} />`
      );

      await click(".post-info.edits button");
      assert.ok(this.historyShown, "clicking the pencil shows the history");
    });

    test("history without view permission", async function (assert) {
      this.set("args", { version: 3, canViewEditHistory: false });
      this.set("showHistory", () => (this.historyShown = true));

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} @showHistory={{this.showHistory}} />`
      );

      await click(".post-info.edits");
      assert.ok(
        !this.historyShown,
        `clicking the pencil doesn't show the history`
      );
    });

    test("whisper", async function (assert) {
      this.set("args", { isWhisper: true });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.strictEqual(count(".topic-post.whisper"), 1);
      assert.strictEqual(count(".post-info.whisper"), 1);
    });

    test("like count button", async function (assert) {
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
      this.set("args", { likeCount: 1 });

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`
      );

      assert.strictEqual(count("button.like-count"), 1);
      assert.ok(!exists(".who-liked"));

      // toggle it on
      await click("button.like-count");
      assert.strictEqual(count(".who-liked"), 1);
      assert.strictEqual(count(".who-liked a.trigger-user-card"), 1);

      // toggle it off
      await click("button.like-count");
      assert.ok(!exists(".who-liked"));
      assert.ok(!exists(".who-liked a.trigger-user-card"));
    });

    test("like count with no likes", async function (assert) {
      this.post.likeAction.count = 0;
      this.set("args", { likeCount: 0 });

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`
      );

      assert.ok(!exists("button.like-count"));
    });

    test("share button", async function (assert) {
      this.siteSettings.post_menu += "|share";
      this.set("args", { shareUrl: "http://share-me.example.com" });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(exists(".actions button.share"), "it renders a share button");
    });

    test("copy link button", async function (assert) {
      this.set("args", { shareUrl: "http://share-me.example.com" });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(
        exists(".actions button.post-action-menu__copy-link"),
        "it renders a copy link button"
      );
    });

    test("liking", async function (assert) {
      const args = { showLike: true, canToggleLike: true, id: 5 };
      this.set("args", args);
      this.set("toggleLike", () => {
        args.liked = !args.liked;
        args.likeCount = args.liked ? 1 : 0;
      });

      await render(
        hbs`
        <MountWidget @widget="post-menu" @args={{this.args}} @toggleLike={{this.toggleLike}} />`
      );

      assert.ok(exists(".actions button.like"));
      assert.ok(!exists(".actions button.like-count"));

      await click(".actions button.like");
      assert.ok(!exists(".actions button.like"));
      assert.ok(exists(".actions button.has-like"));
      assert.strictEqual(count(".actions button.like-count"), 1);

      await click(".actions button.has-like");
      assert.ok(exists(".actions button.like"));
      assert.ok(!exists(".actions button.has-like"));
      assert.ok(!exists(".actions button.like-count"));
    });

    test("anon liking", async function (assert) {
      this.owner.unregister("service:current-user");
      const args = { showLike: true };
      this.set("args", args);
      this.set("showLogin", () => (this.loginShown = true));

      await render(
        hbs`
        <MountWidget @widget="post-menu" @args={{this.args}} @showLogin={{this.showLogin}} />`
      );

      assert.ok(exists(".actions button.like"));
      assert.ok(!exists(".actions button.like-count"));

      assert.strictEqual(
        query("button.like").getAttribute("title"),
        I18n.t("post.controls.like"),
        `shows the right button title for anonymous users`
      );

      await click(".actions button.like");
      assert.ok(this.loginShown);
    });

    test("edit button", async function (assert) {
      this.post.can_edit = true;
      this.set("editPost", () => (this.editPostCalled = true));

      this.set("args", { canEdit: true });

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} @editPost={{this.editPost}} />`
      );

      await click("button.edit");
      assert.ok(this.editPostCalled, "it triggered the edit action");
    });

    test(`edit button - can't edit`, async function (assert) {
      this.post.can_edit = false;
      this.set("args", { canEdit: false });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(!exists("button.edit"), "button is not displayed");
    });

    test("delete topic button", async function (assert) {
      this.post.topic.details.can_delete = true;
      this.set("deletePost", () => (this.deletePostCalled = true));

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} @deletePost={{this.deletePost}} />`
      );

      await click("button.delete");
      assert.ok(this.deletePostCalled, "it triggered the delete action");
    });

    test(`delete topic button - can't delete`, async function (assert) {
      this.post.topic.details.can_delete = false;

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(!exists("button.delete"), `button is not displayed`);
    });

    test(`delete topic button - can't delete when topic author without permission`, async function (assert) {
      this.post.topic.details.can_delete = false;
      this.post.yours = false;

      this.set("args", {
        canDeleteTopic: false,
        showFlagDelete: true,
        canFlag: true,
      });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.strictEqual(count("button.create-flag"), 1, `button is displayed`);
      assert.strictEqual(count("button.delete"), 1, `button is displayed`);
      assert.strictEqual(
        query("button.delete").getAttribute("title"),
        I18n.t("post.controls.delete_topic_disallowed"),
        `shows the right button title for users without permissions`
      );
    });

    test("recover topic button", async function (assert) {
      this.set("args", { canRecoverTopic: true });
      this.set("recoverPost", () => (this.recovered = true));

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} @recoverPost={{this.recoverPost}} />`
      );

      await click("button.recover");
      assert.ok(this.recovered);
    });

    test(`recover topic button - can't recover`, async function (assert) {
      this.set("args", { canRecoverTopic: false });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(!exists("button.recover"), `button is not displayed`);
    });

    test("delete post button", async function (assert) {
      this.set("args", { canDelete: true, canFlag: true });
      this.set("deletePost", () => (this.deletePostCalled = true));

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} @deletePost={{this.deletePost}} />`
      );

      await click("button.delete");
      assert.ok(this.deletePostCalled, "it triggered the delete action");
    });

    test(`delete post button - can't delete`, async function (assert) {
      this.set("args", { canDelete: false });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(!exists("button.delete"), `button is not displayed`);
    });

    test(`delete post button - can't delete, can't flag`, async function (assert) {
      this.set("args", {
        canDeleteTopic: false,
        showFlagDelete: false,
        canFlag: false,
      });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(!exists("button.delete"), `delete button is not displayed`);
      assert.ok(!exists("button.create-flag"), `flag button is not displayed`);
    });

    test("recover post button", async function (assert) {
      this.set("args", { canRecover: true });
      this.set("recoverPost", () => (this.recovered = true));

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} @recoverPost={{this.recoverPost}} />`
      );

      await click("button.recover");
      assert.ok(this.recovered);
    });

    test(`recover post button - can't recover`, async function (assert) {
      this.set("args", { canRecover: false });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(!exists("button.recover"), `button is not displayed`);
    });

    test(`flagging`, async function (assert) {
      this.set("args", { canFlag: true });
      this.set("showFlags", () => (this.flagsShown = true));

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} @showFlags={{this.showFlags}} />`
      );

      assert.strictEqual(count("button.create-flag"), 1);

      await click("button.create-flag");
      assert.ok(this.flagsShown, "it triggered the action");
    });

    test(`flagging: can't flag`, async function (assert) {
      this.set("args", { canFlag: false });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(!exists("button.create-flag"));
    });

    test(`flagging: can't flag when post is hidden`, async function (assert) {
      this.set("args", { canFlag: true, hidden: true });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(!exists("button.create-flag"));
    });

    test(`read indicator`, async function (assert) {
      this.set("args", { read: true });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(exists(".read-state.read"));
    });

    test(`unread indicator`, async function (assert) {
      this.set("args", { read: false });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(exists(".read-state"));
    });

    test("reply directly above (suppressed)", async function (assert) {
      this.set("args", {
        replyToUsername: "eviltrout",
        replyToAvatarTemplate: "/images/avatar.png",
        replyDirectlyAbove: true,
      });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(!exists("a.reply-to-tab"), "hides the tab");
      assert.ok(!exists(".avoid-tab"), "doesn't have the avoid tab class");
    });

    test("reply a few posts above (suppressed)", async function (assert) {
      this.set("args", {
        replyToUsername: "eviltrout",
        replyToAvatarTemplate: "/images/avatar.png",
        replyDirectlyAbove: false,
      });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(exists("a.reply-to-tab"), "shows the tab");
      assert.strictEqual(count(".avoid-tab"), 1, "has the avoid tab class");
    });

    test("reply directly above", async function (assert) {
      this.set("args", {
        replyToUsername: "eviltrout",
        replyToAvatarTemplate: "/images/avatar.png",
        replyDirectlyAbove: true,
      });
      this.siteSettings.suppress_reply_directly_above = false;

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.strictEqual(count(".avoid-tab"), 1, "has the avoid tab class");
      await click("a.reply-to-tab");
      assert.strictEqual(count("section.embedded-posts.top .cooked"), 1);
      assert.strictEqual(count("section.embedded-posts .d-icon-arrow-up"), 1);
    });

    test("cooked content hidden", async function (assert) {
      this.set("args", { cooked_hidden: true, canSeeHiddenPost: true });
      this.set("expandHidden", () => (this.unhidden = true));

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} @expandHidden={{this.expandHidden}} />`
      );

      await click(".topic-body .expand-hidden");
      assert.ok(this.unhidden, "triggers the action");
    });

    test(`cooked content hidden - can't view hidden post`, async function (assert) {
      this.set("args", { cooked_hidden: true, canSeeHiddenPost: false });
      this.set("expandHidden", () => (this.unhidden = true));

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} @expandHidden={{this.expandHidden}} />`
      );

      assert.ok(
        !exists(".topic-body .expand-hidden"),
        "button is not displayed"
      );
    });

    test("expand first post", async function (assert) {
      const store = getOwner(this).lookup("service:store");
      this.set("args", { expandablePost: true });
      this.set("post", store.createRecord("post", { id: 1234 }));

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`
      );

      await click(".topic-body .expand-post");
      assert.ok(!exists(".expand-post"), "button is gone");
    });

    test("can't bookmark", async function (assert) {
      this.set("args", { canBookmark: false });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(!exists("button.bookmark"));
      assert.ok(!exists("button.bookmarked"));
    });

    test("bookmark", async function (assert) {
      const args = { canBookmark: true };

      this.set("args", args);
      this.set("toggleBookmark", () => (args.bookmarked = true));

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} @toggleBookmark={{this.toggleBookmark}} />`
      );

      assert.strictEqual(count(".post-menu-area .bookmark"), 1);
      assert.ok(!exists("button.bookmarked"));
    });

    test("can't show admin menu when you can't manage", async function (assert) {
      this.set("args", { canManage: false });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(!exists(".post-menu-area .show-post-admin-menu"));
    });

    test("show admin menu", async function (assert) {
      this.set("args", { canManage: true });

      await render(
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />
        <DMenus/>`
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
        hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}}
                     @permanentlyDeletePost={{this.permanentlyDeletePost}} />
        <DMenus/>`
      );

      await click(".post-menu-area .show-post-admin-menu");
      await click(
        "[data-content][data-identifier='admin-post-menu'] .permanently-delete"
      );
      assert.ok(this.deleted);
      assert
        .dom("[data-content][data-identifier='admin-post-menu']")
        .doesNotExist("also hides the menu");
    });

    test("permanently delete post", async function (assert) {
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

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}}
                   @permanentlyDeletePost={{this.permanentlyDeletePost}} />
      <DMenus/>
    `);

      await click(".post-menu-area .show-post-admin-menu");

      await click(
        "[data-content][data-identifier='admin-post-menu'] .permanently-delete"
      );
      assert.ok(this.deleted);
      assert
        .dom("[data-content][data-identifier='admin-post-menu']")
        .doesNotExist("also hides the menu");
    });

    test("toggle moderator post", async function (assert) {
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

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}}
                   @togglePostType={{this.togglePostType}} />
      <DMenus/>`);

      await click(".post-menu-area .show-post-admin-menu");
      await click(
        "[data-content][data-identifier='admin-post-menu'] .toggle-post-type"
      );

      assert.ok(this.toggled);
      assert
        .dom("[data-content][data-identifier='admin-post-menu']")
        .doesNotExist("also hides the menu");
    });

    test("rebake post", async function (assert) {
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

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}}
                   @rebakePost={{this.rebakePost}} />
      <DMenus/>`);

      await click(".post-menu-area .show-post-admin-menu");
      await click(
        "[data-content][data-identifier='admin-post-menu'] .rebuild-html"
      );
      assert.ok(this.baked);
      assert
        .dom("[data-content][data-identifier='admin-post-menu']")
        .doesNotExist("also hides the menu");
    });

    test("unhide post", async function (assert) {
      let unhidden;

      this.currentUser.admin = true;
      this.post.hidden = true;
      this.set("args", { canManage: true });
      this.set("unhidePost", () => (unhidden = true));

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}}
                   @unhidePost={{this.unhidePost}} />
      <DMenus/>
    `);

      await click(".post-menu-area .show-post-admin-menu");

      await click(
        "[data-content][data-identifier='admin-post-menu'] .unhide-post"
      );

      assert.ok(unhidden);

      assert
        .dom("[data-content][data-identifier='admin-post-menu']")
        .doesNotExist("also hides the menu");
    });

    test("change owner", async function (assert) {
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

      await render(hbs`
        <MountWidget @widget="post" @model={{this.post}} @args={{this.args}}
                     @changePostOwner={{this.changePostOwner}} />
        <DMenus/>
      `);

      await click(".post-menu-area .show-post-admin-menu");
      await click(
        "[data-content][data-identifier='admin-post-menu'] .change-owner"
      );
      assert.ok(this.owned);
      assert
        .dom("[data-content][data-identifier='admin-post-menu']")
        .doesNotExist("also hides the menu");
    });

    test("reply", async function (assert) {
      this.set("args", { canCreatePost: true });
      this.set("replyToPost", () => (this.replied = true));

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} @replyToPost={{this.replyToPost}} />
    `);

      await click(".post-controls .create");
      assert.ok(this.replied);
    });

    test("reply - without permissions", async function (assert) {
      this.set("args", { canCreatePost: false });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(!exists(".post-controls .create"));
    });

    test("replies - no replies", async function (assert) {
      this.set("args", { replyCount: 0 });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(!exists("button.show-replies"));
    });

    test("replies - multiple replies", async function (assert) {
      this.siteSettings.suppress_reply_directly_below = true;
      this.set("args", { replyCount: 2, replyDirectlyBelow: true });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.strictEqual(count("button.show-replies"), 1);
    });

    test("replies - one below, suppressed", async function (assert) {
      this.siteSettings.suppress_reply_directly_below = true;
      this.set("args", { replyCount: 1, replyDirectlyBelow: true });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(!exists("button.show-replies"));
    });

    test("replies - one below, not suppressed", async function (assert) {
      this.siteSettings.suppress_reply_directly_below = false;
      this.set("args", { id: 6654, replyCount: 1, replyDirectlyBelow: true });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      await click("button.show-replies");
      assert.strictEqual(count("section.embedded-posts.bottom .cooked"), 1);
      assert.strictEqual(count("section.embedded-posts .d-icon-arrow-down"), 1);
    });

    test("shows the topic map when setting the 'topicMap' attribute", async function (assert) {
      const store = getOwner(this).lookup("service:store");
      const topic = store.createRecord("topic", { id: 123 });
      this.set("args", { topic, post_number: 1, topicMap: true });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.dom(".topic-map").exists();
    });

    test("shows the topic map when no replies", async function (assert) {
      this.siteSettings.show_topic_map_in_topics_without_replies = true;

      const store = getOwner(this).lookup("service:store");
      const topic = store.createRecord("topic", {
        id: 123,
        archetype: "regular",
      });
      this.set("args", { topic, post_number: 1 });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.dom(".topic-map").exists();
    });

    test("topic map - few participants", async function (assert) {
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

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);
      assert.dom(".topic-map__users-trigger").doesNotExist();
      assert.dom(".topic-map__users-list a.poster").exists({ count: 2 });
    });

    test("topic map - participants", async function (assert) {
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

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);
      assert.dom(".topic-map__users-list a.poster").exists({ count: 5 });

      await click(".topic-map__users-trigger");
      assert
        .dom(".topic-map__users-content .topic-map__users-list a.poster")
        .exists({ count: 6 });
    });

    test("topic map - links", async function (assert) {
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

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.dom(".topic-map").exists({ count: 1 });
      assert.dom(".topic-map__links-content").doesNotExist();
      await click(".topic-map__links-trigger");
      assert.dom(".topic-map__links-content").exists({ count: 1 });
      assert.dom(".topic-map__links-content .topic-link").exists({ count: 5 });
      await click(".link-summary");
      assert.dom(".topic-map__links-content .topic-link").exists({ count: 6 });
    });

    test("topic map - no top reply summary", async function (assert) {
      const store = getOwner(this).lookup("service:store");
      const topic = store.createRecord("topic", {
        id: 123,
        archetype: "regular",
        posts_count: 2,
      });
      this.set("args", { topic, post_number: 1 });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.dom(".topic-map").exists();
      assert.dom(".summarization-button .top-replies").doesNotExist();
    });

    test("topic map - has top replies summary", async function (assert) {
      const store = getOwner(this).lookup("service:store");
      const topic = store.createRecord("topic", {
        id: 123,
        archetype: "regular",
        posts_count: 2,
        has_summary: true,
      });
      this.set("args", { topic, post_number: 1 });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.dom(".summarization-button .top-replies").exists({ count: 1 });
    });

    test("pm map", async function (assert) {
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

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.dom(".topic-map__private-message-map").exists({ count: 1 });
      assert.dom(".topic-map__private-message-map .user").exists({ count: 1 });
    });

    test("post notice - with username", async function (assert) {
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

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.strictEqual(
        query(".post-notice.returning-user:not(.old)").innerText.trim(),
        I18n.t("post.notice.returning_user", {
          user: "codinghorror",
          time: "2 days ago",
        })
      );
    });

    test("post notice - with name", async function (assert) {
      this.siteSettings.display_name_on_posts = true;
      this.siteSettings.prioritize_username_in_ux = false;
      this.siteSettings.old_post_notice_days = 14;
      this.set("args", {
        username: "codinghorror",
        name: "Jeff",
        created_at: new Date(2019, 0, 1),
        notice: { type: "new_user" },
      });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.strictEqual(
        query(".post-notice.old.new-user").innerText.trim(),
        I18n.t("post.notice.new_user", { user: "Jeff", time: "Jan '10" })
      );
    });

    test("show group request in post", async function (assert) {
      this.set("args", {
        username: "foo",
        requestedGroupName: "testGroup",
      });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      const link = query(".group-request a");
      assert.strictEqual(
        link.innerText.trim(),
        I18n.t("groups.requests.handle")
      );
      assert.strictEqual(
        link.getAttribute("href"),
        "/g/testGroup/requests?filter=foo"
      );
    });

    test("shows user status if enabled in site settings", async function (assert) {
      this.siteSettings.enable_user_status = true;
      const status = {
        emoji: "tooth",
        description: "off to dentist",
      };
      const store = getOwner(this).lookup("service:store");
      const user = store.createRecord("user", { status });
      this.set("args", { user });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.ok(exists(".user-status-message"));
    });

    test("doesn't show user status if disabled in site settings", async function (assert) {
      this.siteSettings.enable_user_status = false;
      const status = {
        emoji: "tooth",
        description: "off to dentist",
      };
      const store = getOwner(this).lookup("service:store");
      const user = store.createRecord("user", { status });
      this.set("args", { user });

      await render(hbs`
      <MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`);

      assert.notOk(exists(".user-status-message"));
    });
  }
);
