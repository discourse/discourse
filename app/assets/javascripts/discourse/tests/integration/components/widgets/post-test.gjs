// deprecated in favor of ./post-test-with-glimmer-post-menu.js

import EmberObject from "@ember/object";
import { getOwner } from "@ember/owner";
import { click, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import MountWidget from "discourse/components/mount-widget";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import DMenus from "float-kit/components/d-menus";

module("Integration | Component | Widget | post", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.glimmer_post_menu_mode = "disabled";
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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
        <MountWidget @widget="post-contents" @args={{self.args}} />
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
        <MountWidget @widget="post-contents" @args={{self.args}} />
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
          @args={{self.args}}
          @showHistory={{self.showHistory}}
        />
      </template>
    );

    await click(".post-info.edits");
    assert.false(
      this.historyShown,
      "clicking the pencil doesn't show the history"
    );
  });

  test("whisper", async function (assert) {
    const self = this;

    this.set("args", { isWhisper: true });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom(".topic-post.whisper").exists();
    assert.dom(".post-info.whisper").exists();
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("like count button", async function (assert) {
    const self = this;

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
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom("button.like-count").exists();
    assert.dom(".who-liked").doesNotExist();

    // toggle it on
    await click("button.like-count");
    assert.dom(".who-liked").exists();
    assert.dom(".who-liked a.trigger-user-card").exists();

    // toggle it off
    await click("button.like-count");
    assert.dom(".who-liked").doesNotExist();
    assert.dom(".who-liked a.trigger-user-card").doesNotExist();
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("like count with no likes", async function (assert) {
    const self = this;

    this.set("args", { likeCount: 0 });

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    assert.dom("button.like-count").doesNotExist();
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("share button", async function (assert) {
    const self = this;

    this.siteSettings.post_menu += "|share";
    this.set("args", { shareUrl: "http://share-me.example.com" });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom(".actions button.share").exists("renders a share button");
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("copy link button", async function (assert) {
    const self = this;

    this.set("args", { shareUrl: "http://share-me.example.com" });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert
      .dom(".actions button.post-action-menu__copy-link")
      .exists("renders a copy link button");
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("liking", async function (assert) {
    const self = this;

    const args = { showLike: true, canToggleLike: true, id: 5 };
    this.set("args", args);
    this.set("toggleLike", () => {
      args.liked = !args.liked;
      args.likeCount = args.liked ? 1 : 0;
    });

    await render(
      <template>
        <MountWidget
          @widget="post-menu"
          @args={{self.args}}
          @toggleLike={{self.toggleLike}}
        />
      </template>
    );

    assert.dom(".actions button.like").exists();
    assert.dom(".actions button.like-count").doesNotExist();

    await click(".actions button.like");
    assert.dom(".actions button.like").doesNotExist();
    assert.dom(".actions button.has-like").exists();
    assert.dom(".actions button.like-count").exists();

    await click(".actions button.has-like");
    assert.dom(".actions button.like").exists();
    assert.dom(".actions button.has-like").doesNotExist();
    assert.dom(".actions button.like-count").doesNotExist();
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("anon liking", async function (assert) {
    const self = this;

    this.owner.unregister("service:current-user");
    const args = { showLike: true };
    this.set("args", args);
    this.set("showLogin", () => (this.loginShown = true));

    await render(
      <template>
        <MountWidget
          @widget="post-menu"
          @args={{self.args}}
          @showLogin={{self.showLogin}}
        />
      </template>
    );

    assert.dom(".actions button.like").exists();
    assert.dom(".actions button.like-count").doesNotExist();

    assert
      .dom("button.like")
      .hasAttribute(
        "title",
        i18n("post.controls.like"),
        "shows the right button title for anonymous users"
      );

    await click(".actions button.like");
    assert.true(this.loginShown);
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("edit button", async function (assert) {
    const self = this;

    this.set("args", { canEdit: true });
    this.set("editPost", () => (this.editPostCalled = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @args={{self.args}}
          @editPost={{self.editPost}}
        />
      </template>
    );

    await click("button.edit");
    assert.true(this.editPostCalled, "triggered the edit action");
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test(`edit button - can't edit`, async function (assert) {
    const self = this;

    this.set("args", { canEdit: false });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom("button.edit").doesNotExist("button is not displayed");
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("delete topic button", async function (assert) {
    const self = this;

    this.set("args", { canDeleteTopic: true });
    this.set("deletePost", () => (this.deletePostCalled = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @args={{self.args}}
          @deletePost={{self.deletePost}}
        />
      </template>
    );

    await click("button.delete");
    assert.true(this.deletePostCalled, "triggered the delete action");
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test(`delete topic button - can't delete`, async function (assert) {
    const self = this;

    this.set("args", { canDeleteTopic: false });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom("button.delete").doesNotExist("button is not displayed");
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test(`delete topic button - can't delete when topic author without permission`, async function (assert) {
    const self = this;

    this.set("args", {
      canDeleteTopic: false,
      showFlagDelete: true,
      canFlag: true,
    });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    await click(".show-more-actions");

    assert.dom("button.create-flag").exists("button is displayed");
    assert.dom("button.delete").exists("button is displayed");
    assert
      .dom("button.delete")
      .hasAttribute(
        "title",
        i18n("post.controls.delete_topic_disallowed"),
        "shows the right button title for users without permissions"
      );
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("recover topic button", async function (assert) {
    const self = this;

    this.set("args", { canRecoverTopic: true });
    this.set("recoverPost", () => (this.recovered = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @args={{self.args}}
          @recoverPost={{self.recoverPost}}
        />
      </template>
    );

    await click("button.recover");
    assert.true(this.recovered);
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test(`recover topic button - can't recover`, async function (assert) {
    const self = this;

    this.set("args", { canRecoverTopic: false });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom("button.recover").doesNotExist("button is not displayed");
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("delete post button", async function (assert) {
    const self = this;

    this.set("args", { canDelete: true, canFlag: true });
    this.set("deletePost", () => (this.deletePostCalled = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @args={{self.args}}
          @deletePost={{self.deletePost}}
        />
      </template>
    );

    await click(".show-more-actions");
    await click("button.delete");
    assert.true(this.deletePostCalled, "triggered the delete action");
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test(`delete post button - can't delete`, async function (assert) {
    const self = this;

    this.set("args", { canDelete: false });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom("button.delete").doesNotExist("button is not displayed");
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test(`delete post button - can't delete, can't flag`, async function (assert) {
    const self = this;

    this.set("args", {
      canDeleteTopic: false,
      showFlagDelete: false,
      canFlag: false,
    });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom("button.delete").doesNotExist("delete button is not displayed");
    assert
      .dom("button.create-flag")
      .doesNotExist("flag button is not displayed");
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("recover post button", async function (assert) {
    const self = this;

    this.set("args", { canRecover: true });
    this.set("recoverPost", () => (this.recovered = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @args={{self.args}}
          @recoverPost={{self.recoverPost}}
        />
      </template>
    );

    await click("button.recover");
    assert.true(this.recovered);
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test(`recover post button - can't recover`, async function (assert) {
    const self = this;

    this.set("args", { canRecover: false });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom("button.recover").doesNotExist("button is not displayed");
  });

  test(`flagging`, async function (assert) {
    const self = this;

    this.set("args", { canFlag: true });
    this.set("showFlags", () => (this.flagsShown = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @args={{self.args}}
          @showFlags={{self.showFlags}}
        />
      </template>
    );

    assert.dom("button.create-flag").exists();

    await click("button.create-flag");
    assert.true(this.flagsShown, "triggered the action");
  });

  test(`flagging: can't flag`, async function (assert) {
    const self = this;

    this.set("args", { canFlag: false });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom("button.create-flag").doesNotExist();
  });

  test(`flagging: can't flag when post is hidden`, async function (assert) {
    const self = this;

    this.set("args", { canFlag: true, hidden: true });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom("button.create-flag").doesNotExist();
  });

  test(`read indicator`, async function (assert) {
    const self = this;

    this.set("args", { read: true });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom(".read-state.read").exists();
  });

  test(`unread indicator`, async function (assert) {
    const self = this;

    this.set("args", { read: false });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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

    const store = getOwner(this).lookup("service:store");
    this.set("args", { expandablePost: true });
    this.set("post", store.createRecord("post", { id: 1234 }));

    await render(
      <template>
        <MountWidget @widget="post" @model={{self.post}} @args={{self.args}} />
      </template>
    );

    await click(".topic-body .expand-post");
    assert.dom(".expand-post").doesNotExist("button is gone");
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("can't bookmark", async function (assert) {
    const self = this;

    this.set("args", { canBookmark: false });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom("button.bookmark").doesNotExist();
    assert.dom("button.bookmarked").doesNotExist();
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("bookmark", async function (assert) {
    const self = this;

    const args = { canBookmark: true };

    this.set("args", args);
    this.set("toggleBookmark", () => (args.bookmarked = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @args={{self.args}}
          @toggleBookmark={{self.toggleBookmark}}
        />
      </template>
    );

    assert.dom(".post-menu-area .bookmark").exists();
    assert.dom("button.bookmarked").doesNotExist();
  });

  test("can't show admin menu when you can't manage", async function (assert) {
    const self = this;

    this.set("args", { canManage: false });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom(".post-menu-area .show-post-admin-menu").doesNotExist();
  });

  test("show admin menu", async function (assert) {
    const self = this;

    this.set("args", { canManage: true });

    await render(
      <template>
        <MountWidget @widget="post" @args={{self.args}} />
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
          @args={{self.args}}
          @model={{self.post}}
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
          @args={{self.args}}
          @model={{self.post}}
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
          @args={{self.args}}
          @model={{self.post}}
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
          @args={{self.args}}
          @model={{self.post}}
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
    this.set("unhidePost", () => (unhidden = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @args={{self.args}}
          @model={{self.post}}
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
          @args={{self.args}}
          @model={{self.post}}
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

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("reply", async function (assert) {
    const self = this;

    this.set("args", { canCreatePost: true });
    this.set("replyToPost", () => (this.replied = true));

    await render(
      <template>
        <MountWidget
          @widget="post"
          @args={{self.args}}
          @replyToPost={{self.replyToPost}}
        />
      </template>
    );

    await click(".post-controls .create");
    assert.true(this.replied);
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("reply - without permissions", async function (assert) {
    const self = this;

    this.set("args", { canCreatePost: false });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom(".post-controls .create").doesNotExist();
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("replies - no replies", async function (assert) {
    const self = this;

    this.set("args", { replyCount: 0 });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom("button.show-replies").doesNotExist();
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("replies - multiple replies", async function (assert) {
    const self = this;

    this.siteSettings.suppress_reply_directly_below = true;
    this.set("args", { replyCount: 2, replyDirectlyBelow: true });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom("button.show-replies").exists();
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("replies - one below, suppressed", async function (assert) {
    const self = this;

    this.siteSettings.suppress_reply_directly_below = true;
    this.set("args", { replyCount: 1, replyDirectlyBelow: true });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom("button.show-replies").doesNotExist();
  });

  // glimmer-post-menu: deprecated in favor of spec/system/post_menu_spec.rb
  test("replies - one below, not suppressed", async function (assert) {
    const self = this;

    this.siteSettings.suppress_reply_directly_below = false;
    this.set("args", { id: 6654, replyCount: 1, replyDirectlyBelow: true });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    await click("button.show-replies");
    assert.dom("section.embedded-posts.bottom .cooked").exists();
    assert.dom("section.embedded-posts .d-icon-arrow-down").exists();
  });

  test("shows the topic map when setting the 'topicMap' attribute", async function (assert) {
    const self = this;

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 123 });
    this.set("args", { topic, post_number: 1, topicMap: true });

    await render(
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom(".topic-map").exists({ count: 1 });
    assert.dom(".topic-map__links-content").doesNotExist();
    await click(".topic-map__links-trigger");
    assert.dom(".topic-map__links-content").exists({ count: 1 });
    assert.dom(".topic-map__links-content .topic-link").exists({ count: 5 });
    await click(".link-summary");
    assert.dom(".topic-map__links-content .topic-link").exists({ count: 6 });
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom(".topic-map").exists();
    assert.dom(".summarization-button .top-replies").doesNotExist();
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom(".summarization-button .top-replies").exists({ count: 1 });
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
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
      <template><MountWidget @widget="post" @args={{self.args}} /></template>
    );

    assert.dom(".user-status-message").doesNotExist();
  });
});
