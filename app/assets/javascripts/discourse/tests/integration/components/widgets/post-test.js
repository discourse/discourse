import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import {
  count,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import EmberObject from "@ember/object";
import I18n from "I18n";
import User from "discourse/models/user";
import { getOwner } from "discourse-common/lib/get-owner";

module("Integration | Component | Widget | post", function (hooks) {
  setupRenderingTest(hooks);

  test("basic elements", async function (assert) {
    this.set("args", { shareUrl: "/example", post_number: 1 });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

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
      hbs`<MountWidget @widget="post-contents" @args={{this.args}} />`
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
      hbs`<MountWidget @widget="post-contents" @args={{this.args}} />`
    );

    assert.strictEqual(count(".badge.clicks"), 2);
    assert.strictEqual(queryAll(".badge.clicks")[0].innerText, "1");
    assert.strictEqual(queryAll(".badge.clicks")[1].innerText, "2");
  });

  test("wiki", async function (assert) {
    this.set("args", { wiki: true, version: 2, canViewEditHistory: true });
    this.set("showHistory", () => (this.historyShown = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @showHistory={{this.showHistory}} />
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
      <MountWidget @widget="post" @args={{this.args}} @editPost={{this.editPost}} />
    `);

    await click(".post-info .wiki");
    assert.ok(this.editPostCalled, "clicking wiki icon edits the post");
  });

  test("via-email", async function (assert) {
    this.set("args", { via_email: true, canViewRawEmail: true });
    this.set("showRawEmail", () => (this.rawEmailShown = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @showRawEmail={{this.showRawEmail}} />
    `);

    await click(".post-info.via-email");
    assert.ok(this.rawEmailShown, "clicking the envelope shows the raw email");
  });

  test("via-email without permission", async function (assert) {
    this.set("args", { via_email: true, canViewRawEmail: false });
    this.set("showRawEmail", () => (this.rawEmailShown = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @showRawEmail={{this.showRawEmail}} />
    `);

    await click(".post-info.via-email");
    assert.ok(
      !this.rawEmailShown,
      "clicking the envelope doesn't show the raw email"
    );
  });

  test("history", async function (assert) {
    this.set("args", { version: 3, canViewEditHistory: true });
    this.set("showHistory", () => (this.historyShown = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @showHistory={{this.showHistory}} />
    `);

    await click(".post-info.edits button");
    assert.ok(this.historyShown, "clicking the pencil shows the history");
  });

  test("history without view permission", async function (assert) {
    this.set("args", { version: 3, canViewEditHistory: false });
    this.set("showHistory", () => (this.historyShown = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @showHistory={{this.showHistory}} />
    `);

    await click(".post-info.edits");
    assert.ok(
      !this.historyShown,
      `clicking the pencil doesn't show the history`
    );
  });

  test("whisper", async function (assert) {
    this.set("args", { isWhisper: true });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

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
      hbs`<MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`
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

  test(`like count with no likes`, async function (assert) {
    this.set("args", { likeCount: 0 });

    await render(
      hbs`<MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`
    );

    assert.ok(!exists("button.like-count"));
  });

  test("share button", async function (assert) {
    this.set("args", { shareUrl: "http://share-me.example.com" });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(exists(".actions button.share"), "it renders a share button");
  });

  test("liking", async function (assert) {
    const args = { showLike: true, canToggleLike: true, id: 5 };
    this.set("args", args);
    this.set("toggleLike", () => {
      args.liked = !args.liked;
      args.likeCount = args.liked ? 1 : 0;
    });

    await render(hbs`
      <MountWidget @widget="post-menu" @args={{this.args}} @toggleLike={{this.toggleLike}} />
    `);

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

    await render(hbs`
      <MountWidget @widget="post-menu" @args={{this.args}} @showLogin={{this.showLogin}} />
    `);

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
    this.set("args", { canEdit: true });
    this.set("editPost", () => (this.editPostCalled = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @editPost={{this.editPost}} />
    `);

    await click("button.edit");
    assert.ok(this.editPostCalled, "it triggered the edit action");
  });

  test(`edit button - can't edit`, async function (assert) {
    this.set("args", { canEdit: false });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists("button.edit"), "button is not displayed");
  });

  test("recover button", async function (assert) {
    this.set("args", { canDelete: true });
    this.set("deletePost", () => (this.deletePostCalled = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @deletePost={{this.deletePost}} />
    `);

    await click("button.delete");
    assert.ok(this.deletePostCalled, "it triggered the delete action");
  });

  test("delete topic button", async function (assert) {
    this.set("args", { canDeleteTopic: true });
    this.set("deletePost", () => (this.deletePostCalled = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @deletePost={{this.deletePost}} />
    `);

    await click("button.delete");
    assert.ok(this.deletePostCalled, "it triggered the delete action");
  });

  test(`delete topic button - can't delete`, async function (assert) {
    this.set("args", { canDeleteTopic: false });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists("button.delete"), `button is not displayed`);
  });

  test(`delete topic button - can't delete when topic author without permission`, async function (assert) {
    this.set("args", {
      canDeleteTopic: false,
      showFlagDelete: true,
      canFlag: true,
    });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    await click(".show-more-actions");

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

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @recoverPost={{this.recoverPost}} />
    `);

    await click("button.recover");
    assert.ok(this.recovered);
  });

  test(`recover topic button - can't recover`, async function (assert) {
    this.set("args", { canRecoverTopic: false });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists("button.recover"), `button is not displayed`);
  });

  test("delete post button", async function (assert) {
    this.set("args", { canDelete: true, canFlag: true });
    this.set("deletePost", () => (this.deletePostCalled = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @deletePost={{this.deletePost}} />
    `);

    await click(".show-more-actions");
    await click("button.delete");
    assert.ok(this.deletePostCalled, "it triggered the delete action");
  });

  test(`delete post button - can't delete`, async function (assert) {
    this.set("args", { canDelete: false });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists("button.delete"), `button is not displayed`);
  });

  test(`delete post button - can't delete, can't flag`, async function (assert) {
    this.set("args", {
      canDeleteTopic: false,
      showFlagDelete: false,
      canFlag: false,
    });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists("button.delete"), `delete button is not displayed`);
    assert.ok(!exists("button.create-flag"), `flag button is not displayed`);
  });

  test("recover post button", async function (assert) {
    this.set("args", { canRecover: true });
    this.set("recoverPost", () => (this.recovered = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @recoverPost={{this.recoverPost}} />
    `);

    await click("button.recover");
    assert.ok(this.recovered);
  });

  test(`recover post button - can't recover`, async function (assert) {
    this.set("args", { canRecover: false });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists("button.recover"), `button is not displayed`);
  });

  test(`flagging`, async function (assert) {
    this.set("args", { canFlag: true });
    this.set("showFlags", () => (this.flagsShown = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @showFlags={{this.showFlags}} />
    `);

    assert.strictEqual(count("button.create-flag"), 1);

    await click("button.create-flag");
    assert.ok(this.flagsShown, "it triggered the action");
  });

  test(`flagging: can't flag`, async function (assert) {
    this.set("args", { canFlag: false });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists("button.create-flag"));
  });

  test(`flagging: can't flag when post is hidden`, async function (assert) {
    this.set("args", { canFlag: true, hidden: true });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists("button.create-flag"));
  });

  test(`read indicator`, async function (assert) {
    this.set("args", { read: true });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(exists(".read-state.read"));
  });

  test(`unread indicator`, async function (assert) {
    this.set("args", { read: false });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(exists(".read-state"));
  });

  test("reply directly above (suppressed)", async function (assert) {
    this.set("args", {
      replyToUsername: "eviltrout",
      replyToAvatarTemplate: "/images/avatar.png",
      replyDirectlyAbove: true,
    });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists("a.reply-to-tab"), "hides the tab");
    assert.ok(!exists(".avoid-tab"), "doesn't have the avoid tab class");
  });

  test("reply a few posts above (suppressed)", async function (assert) {
    this.set("args", {
      replyToUsername: "eviltrout",
      replyToAvatarTemplate: "/images/avatar.png",
      replyDirectlyAbove: false,
    });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

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

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.strictEqual(count(".avoid-tab"), 1, "has the avoid tab class");
    await click("a.reply-to-tab");
    assert.strictEqual(count("section.embedded-posts.top .cooked"), 1);
    assert.strictEqual(count("section.embedded-posts .d-icon-arrow-up"), 1);
  });

  test("cooked content hidden", async function (assert) {
    this.set("args", { cooked_hidden: true, canSeeHiddenPost: true });
    this.set("expandHidden", () => (this.unhidden = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @expandHidden={{this.expandHidden}} />
    `);

    await click(".topic-body .expand-hidden");
    assert.ok(this.unhidden, "triggers the action");
  });

  test(`cooked content hidden - can't view hidden post`, async function (assert) {
    this.set("args", { cooked_hidden: true, canSeeHiddenPost: false });
    this.set("expandHidden", () => (this.unhidden = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @expandHidden={{this.expandHidden}} />
    `);

    assert.ok(!exists(".topic-body .expand-hidden"), "button is not displayed");
  });

  test("expand first post", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    this.set("args", { expandablePost: true });
    this.set("post", store.createRecord("post", { id: 1234 }));

    await render(
      hbs`<MountWidget @widget="post" @model={{this.post}} @args={{this.args}} />`
    );

    await click(".topic-body .expand-post");
    assert.ok(!exists(".expand-post"), "button is gone");
  });

  test("can't bookmark", async function (assert) {
    this.set("args", { canBookmark: false });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists("button.bookmark"));
    assert.ok(!exists("button.bookmarked"));
  });

  test("bookmark", async function (assert) {
    const args = { canBookmark: true };

    this.set("args", args);
    this.set("toggleBookmark", () => (args.bookmarked = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @toggleBookmark={{this.toggleBookmark}} />
    `);

    assert.strictEqual(count(".post-menu-area .bookmark"), 1);
    assert.ok(!exists("button.bookmarked"));
  });

  test("can't show admin menu when you can't manage", async function (assert) {
    this.set("args", { canManage: false });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists(".post-menu-area .show-post-admin-menu"));
  });

  test("show admin menu", async function (assert) {
    this.set("args", { canManage: true });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists(".post-admin-menu"));
    await click(".post-menu-area .show-post-admin-menu");
    assert.strictEqual(count(".post-admin-menu"), 1, "it shows the popup");
    await click(".post-menu-area");
    assert.ok(!exists(".post-admin-menu"), "clicking outside clears the popup");
  });

  test("permanently delete topic", async function (assert) {
    this.set("args", { canManage: true, canPermanentlyDelete: true });
    this.set("permanentlyDeletePost", () => (this.deleted = true));

    await render(
      hbs`<MountWidget @widget="post" @args={{this.args}} @permanentlyDeletePost={{this.permanentlyDeletePost}} />`
    );

    await click(".post-menu-area .show-post-admin-menu");
    await click(".post-admin-menu .permanently-delete");
    assert.ok(this.deleted);
    assert.ok(!exists(".post-admin-menu"), "also hides the menu");
  });

  test("permanently delete post", async function (assert) {
    this.set("args", { canManage: true, canPermanentlyDelete: true });
    this.set("permanentlyDeletePost", () => (this.deleted = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @permanentlyDeletePost={{this.permanentlyDeletePost}} />
    `);

    await click(".post-menu-area .show-post-admin-menu");
    await click(".post-admin-menu .permanently-delete");
    assert.ok(this.deleted);
    assert.ok(!exists(".post-admin-menu"), "also hides the menu");
  });

  test("toggle moderator post", async function (assert) {
    this.currentUser.set("moderator", true);
    this.set("args", { canManage: true });
    this.set("togglePostType", () => (this.toggled = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @togglePostType={{this.togglePostType}} />
    `);

    await click(".post-menu-area .show-post-admin-menu");
    await click(".post-admin-menu .toggle-post-type");

    assert.ok(this.toggled);
    assert.ok(!exists(".post-admin-menu"), "also hides the menu");
  });

  test("toggle moderator post", async function (assert) {
    this.currentUser.set("moderator", true);
    this.set("args", { canManage: true });
    this.set("togglePostType", () => (this.toggled = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @togglePostType={{this.togglePostType}} />
    `);

    await click(".post-menu-area .show-post-admin-menu");
    await click(".post-admin-menu .toggle-post-type");

    assert.ok(this.toggled);
    assert.ok(!exists(".post-admin-menu"), "also hides the menu");
  });

  test("rebake post", async function (assert) {
    this.set("args", { canManage: true });
    this.set("rebakePost", () => (this.baked = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @rebakePost={{this.rebakePost}} />
    `);

    await click(".post-menu-area .show-post-admin-menu");
    await click(".post-admin-menu .rebuild-html");
    assert.ok(this.baked);
    assert.ok(!exists(".post-admin-menu"), "also hides the menu");
  });

  test("unhide post", async function (assert) {
    this.currentUser.admin = true;
    this.set("args", { canManage: true, hidden: true });
    this.set("unhidePost", () => (this.unhidden = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @unhidePost={{this.unhidePost}} />
    `);

    await click(".post-menu-area .show-post-admin-menu");
    await click(".post-admin-menu .unhide-post");
    assert.ok(this.unhidden);
    assert.ok(!exists(".post-admin-menu"), "also hides the menu");
  });

  test("change owner", async function (assert) {
    this.currentUser.admin = true;
    this.set("args", { canManage: true });
    this.set("changePostOwner", () => (this.owned = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @changePostOwner={{this.changePostOwner}} />
    `);

    await click(".post-menu-area .show-post-admin-menu");
    await click(".post-admin-menu .change-owner");
    assert.ok(this.owned);
    assert.ok(!exists(".post-admin-menu"), "also hides the menu");
  });

  test("reply", async function (assert) {
    this.set("args", { canCreatePost: true });
    this.set("replyToPost", () => (this.replied = true));

    await render(hbs`
      <MountWidget @widget="post" @args={{this.args}} @replyToPost={{this.replyToPost}} />
    `);

    await click(".post-controls .create");
    assert.ok(this.replied);
  });

  test("reply - without permissions", async function (assert) {
    this.set("args", { canCreatePost: false });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists(".post-controls .create"));
  });

  test("replies - no replies", async function (assert) {
    this.set("args", { replyCount: 0 });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists("button.show-replies"));
  });

  test("replies - multiple replies", async function (assert) {
    this.siteSettings.suppress_reply_directly_below = true;
    this.set("args", { replyCount: 2, replyDirectlyBelow: true });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.strictEqual(count("button.show-replies"), 1);
  });

  test("replies - one below, suppressed", async function (assert) {
    this.siteSettings.suppress_reply_directly_below = true;
    this.set("args", { replyCount: 1, replyDirectlyBelow: true });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists("button.show-replies"));
  });

  test("replies - one below, not suppressed", async function (assert) {
    this.siteSettings.suppress_reply_directly_below = false;
    this.set("args", { id: 6654, replyCount: 1, replyDirectlyBelow: true });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    await click("button.show-replies");
    assert.strictEqual(count("section.embedded-posts.bottom .cooked"), 1);
    assert.strictEqual(count("section.embedded-posts .d-icon-arrow-down"), 1);
  });

  test("topic map not shown", async function (assert) {
    this.set("args", { showTopicMap: false });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists(".topic-map"));
  });

  test("topic map - few posts", async function (assert) {
    this.set("args", {
      showTopicMap: true,
      topicPostsCount: 2,
      participants: [{ username: "eviltrout" }, { username: "codinghorror" }],
    });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(
      !exists("li.avatars a.poster"),
      "shows no participants when collapsed"
    );

    await click("nav.buttons button");
    assert.strictEqual(
      count(".topic-map-expanded a.poster"),
      2,
      "shows all when expanded"
    );
  });

  test("topic map - participants", async function (assert) {
    this.set("args", {
      showTopicMap: true,
      topicPostsCount: 10,
      participants: [
        { username: "eviltrout" },
        { username: "codinghorror" },
        { username: "sam" },
        { username: "ZogStrIP" },
      ],
      userFilters: ["sam", "codinghorror"],
    });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.strictEqual(
      count("li.avatars a.poster"),
      3,
      "limits to three participants"
    );

    await click("nav.buttons button");
    assert.ok(!exists("li.avatars a.poster"));
    assert.strictEqual(
      count(".topic-map-expanded a.poster"),
      4,
      "shows all when expanded"
    );
    assert.strictEqual(count("a.poster.toggled"), 2, "two are toggled");
  });

  test("topic map - links", async function (assert) {
    this.set("args", {
      showTopicMap: true,
      topicLinks: [
        { url: "http://link1.example.com", clicks: 0 },
        { url: "http://link2.example.com", clicks: 0 },
        { url: "http://link3.example.com", clicks: 0 },
        { url: "http://link4.example.com", clicks: 0 },
        { url: "http://link5.example.com", clicks: 0 },
        { url: "http://link6.example.com", clicks: 0 },
      ],
    });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.strictEqual(count(".topic-map"), 1);
    assert.strictEqual(count(".map.map-collapsed"), 1);
    assert.ok(!exists(".topic-map-expanded"));

    await click("nav.buttons button");
    assert.ok(!exists(".map.map-collapsed"));
    assert.strictEqual(count(".topic-map .d-icon-chevron-up"), 1);
    assert.strictEqual(count(".topic-map-expanded"), 1);
    assert.strictEqual(
      count(".topic-map-expanded .topic-link"),
      5,
      "it limits the links displayed"
    );

    await click(".link-summary button");
    assert.strictEqual(
      count(".topic-map-expanded .topic-link"),
      6,
      "all links now shown"
    );
  });

  test("topic map - no summary", async function (assert) {
    this.set("args", { showTopicMap: true });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(!exists(".toggle-summary"));
  });

  test("topic map - has top replies summary", async function (assert) {
    this.set("args", { showTopicMap: true, hasTopRepliesSummary: true });
    this.set("showTopReplies", () => (this.summaryToggled = true));

    await render(
      hbs`<MountWidget @widget="post" @args={{this.args}} @showTopReplies={{this.showTopReplies}} />`
    );

    assert.strictEqual(count(".toggle-summary"), 1);

    await click(".toggle-summary button");
    assert.ok(this.summaryToggled);
  });

  test("pm map", async function (assert) {
    this.set("args", {
      showTopicMap: true,
      showPMMap: true,
      allowedGroups: [],
      allowedUsers: [EmberObject.create({ username: "eviltrout" })],
    });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.strictEqual(count(".private-message-map"), 1);
    assert.strictEqual(count(".private-message-map .user"), 1);
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

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

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

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

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

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    const link = query(".group-request a");
    assert.strictEqual(link.innerText.trim(), I18n.t("groups.requests.handle"));
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
    const user = User.create({ status });
    this.set("args", { user });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.ok(exists(".user-status-message"));
  });

  test("doesn't show user status if disabled in site settings", async function (assert) {
    this.siteSettings.enable_user_status = false;
    const status = {
      emoji: "tooth",
      description: "off to dentist",
    };
    const user = User.create({ status });
    this.set("args", { user });

    await render(hbs`<MountWidget @widget="post" @args={{this.args}} />`);

    assert.notOk(exists(".user-status-message"));
  });
});
