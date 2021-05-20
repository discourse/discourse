import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import EmberObject from "@ember/object";
import I18n from "I18n";
import { click } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | Widget | post", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("basic elements", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { shareUrl: "/example", post_number: 1 });
    },
    test(assert) {
      assert.ok(queryAll(".names").length, "includes poster name");

      assert.ok(queryAll("a.post-date").length, "includes post date");
      assert.ok(queryAll("a.post-date[data-share-url]").length);
      assert.ok(queryAll("a.post-date[data-post-number]").length);
    },
  });

  componentTest("post - links", {
    template: hbs`{{mount-widget widget="post-contents" args=args}}`,
    beforeEach() {
      this.set("args", {
        cooked:
          "<a href='http://link1.example.com/'>first link</a> and <a href='http://link2.example.com/?some=query'>second link</a>",
        linkCounts: [
          { url: "http://link1.example.com/", clicks: 1, internal: true },
          { url: "http://link2.example.com/", clicks: 2, internal: true },
        ],
      });
    },
    async test(assert) {
      assert.equal(queryAll(".badge.clicks:nth(0)").text(), "1");
      assert.equal(queryAll(".badge.clicks:nth(1)").text(), "2");
    },
  });

  componentTest("wiki", {
    template: hbs`
      {{mount-widget widget="post" args=args showHistory=showHistory}}
    `,
    beforeEach() {
      this.set("args", { wiki: true, version: 2, canViewEditHistory: true });
      this.set("showHistory", () => (this.historyShown = true));
    },
    async test(assert) {
      await click(".post-info .wiki");
      assert.ok(
        this.historyShown,
        "clicking the wiki icon displays the post history"
      );
    },
  });

  componentTest("wiki without revision", {
    template: hbs`
      {{mount-widget widget="post" args=args editPost=editPost}}
    `,
    beforeEach() {
      this.set("args", { wiki: true, version: 1, canViewEditHistory: true });
      this.set("editPost", () => (this.editPostCalled = true));
    },
    async test(assert) {
      await click(".post-info .wiki");
      assert.ok(this.editPostCalled, "clicking wiki icon edits the post");
    },
  });

  componentTest("via-email", {
    template: hbs`
      {{mount-widget widget="post" args=args showRawEmail=showRawEmail}}
    `,
    beforeEach() {
      this.set("args", { via_email: true, canViewRawEmail: true });
      this.set("showRawEmail", () => (this.rawEmailShown = true));
    },
    async test(assert) {
      await click(".post-info.via-email");
      assert.ok(
        this.rawEmailShown,
        "clicking the envelope shows the raw email"
      );
    },
  });

  componentTest("via-email without permission", {
    template: hbs`
      {{mount-widget widget="post" args=args showRawEmail=showRawEmail}}
    `,
    beforeEach() {
      this.set("args", { via_email: true, canViewRawEmail: false });
      this.set("showRawEmail", () => (this.rawEmailShown = true));
    },
    async test(assert) {
      await click(".post-info.via-email");
      assert.ok(
        !this.rawEmailShown,
        "clicking the envelope doesn't show the raw email"
      );
    },
  });

  componentTest("history", {
    template: hbs`
      {{mount-widget widget="post" args=args showHistory=showHistory}}
    `,
    beforeEach() {
      this.set("args", { version: 3, canViewEditHistory: true });
      this.set("showHistory", () => (this.historyShown = true));
    },
    async test(assert) {
      await click(".post-info.edits button");
      assert.ok(this.historyShown, "clicking the pencil shows the history");
    },
  });

  componentTest("history without view permission", {
    template: hbs`
      {{mount-widget widget="post" args=args showHistory=showHistory}}
    `,
    beforeEach() {
      this.set("args", { version: 3, canViewEditHistory: false });
      this.set("showHistory", () => (this.historyShown = true));
    },
    async test(assert) {
      await click(".post-info.edits");
      assert.ok(
        !this.historyShown,
        `clicking the pencil doesn't show the history`
      );
    },
  });

  componentTest("whisper", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { isWhisper: true });
    },
    test(assert) {
      assert.ok(queryAll(".topic-post.whisper").length === 1);
      assert.ok(queryAll(".post-info.whisper").length === 1);
    },
  });

  componentTest("like count button", {
    template: hbs`{{mount-widget widget="post" model=post args=args}}`,
    beforeEach(store) {
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
    },
    async test(assert) {
      assert.ok(queryAll("button.like-count").length === 1);
      assert.ok(queryAll(".who-liked").length === 0);

      // toggle it on
      await click("button.like-count");
      assert.ok(queryAll(".who-liked").length === 1);
      assert.ok(queryAll(".who-liked a.trigger-user-card").length === 1);

      // toggle it off
      await click("button.like-count");
      assert.ok(queryAll(".who-liked").length === 0);
      assert.ok(queryAll(".who-liked a.trigger-user-card").length === 0);
    },
  });

  componentTest(`like count with no likes`, {
    template: hbs`{{mount-widget widget="post" model=post args=args}}`,
    beforeEach() {
      this.set("args", { likeCount: 0 });
    },
    test(assert) {
      assert.ok(queryAll("button.like-count").length === 0);
    },
  });

  componentTest("share button", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { shareUrl: "http://share-me.example.com" });
    },
    test(assert) {
      assert.ok(
        !!queryAll(".actions button[data-share-url]").length,
        "it renders a share button"
      );
    },
  });

  componentTest("liking", {
    template: hbs`
      {{mount-widget widget="post-menu" args=args toggleLike=toggleLike}}
    `,
    beforeEach() {
      const args = { showLike: true, canToggleLike: true };
      this.set("args", args);
      this.set("toggleLike", () => {
        args.liked = !args.liked;
        args.likeCount = args.liked ? 1 : 0;
      });
    },
    async test(assert) {
      assert.ok(!!queryAll(".actions button.like").length);
      assert.ok(queryAll(".actions button.like-count").length === 0);

      await click(".actions button.like");
      assert.ok(!queryAll(".actions button.like").length);
      assert.ok(!!queryAll(".actions button.has-like").length);
      assert.ok(queryAll(".actions button.like-count").length === 1);

      await click(".actions button.has-like");
      assert.ok(!!queryAll(".actions button.like").length);
      assert.ok(!queryAll(".actions button.has-like").length);
      assert.ok(queryAll(".actions button.like-count").length === 0);
    },
  });

  componentTest("anon liking", {
    template: hbs`
      {{mount-widget widget="post-menu" args=args showLogin=showLogin}}
    `,
    anonymous: true,
    beforeEach() {
      const args = { showLike: true };
      this.set("args", args);
      this.set("showLogin", () => (this.loginShown = true));
    },
    async test(assert) {
      assert.ok(!!queryAll(".actions button.like").length);
      assert.ok(queryAll(".actions button.like-count").length === 0);

      assert.equal(
        queryAll("button.like").attr("title"),
        I18n.t("post.controls.like"),
        `shows the right button title for anonymous users`
      );

      await click(".actions button.like");
      assert.ok(this.loginShown);
    },
  });

  componentTest("edit button", {
    template: hbs`
      {{mount-widget widget="post" args=args editPost=editPost}}
    `,
    beforeEach() {
      this.set("args", { canEdit: true });
      this.set("editPost", () => (this.editPostCalled = true));
    },
    async test(assert) {
      await click("button.edit");
      assert.ok(this.editPostCalled, "it triggered the edit action");
    },
  });

  componentTest(`edit button - can't edit`, {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { canEdit: false });
    },
    test(assert) {
      assert.equal(
        queryAll("button.edit").length,
        0,
        `button is not displayed`
      );
    },
  });

  componentTest("recover button", {
    template: hbs`
      {{mount-widget widget="post" args=args deletePost=deletePost}}
    `,
    beforeEach() {
      this.set("args", { canDelete: true });
      this.set("deletePost", () => (this.deletePostCalled = true));
    },
    async test(assert) {
      await click("button.delete");
      assert.ok(this.deletePostCalled, "it triggered the delete action");
    },
  });

  componentTest("delete topic button", {
    template: hbs`
      {{mount-widget widget="post" args=args deletePost=deletePost}}
    `,
    beforeEach() {
      this.set("args", { canDeleteTopic: true });
      this.set("deletePost", () => (this.deletePostCalled = true));
    },
    async test(assert) {
      await click("button.delete");
      assert.ok(this.deletePostCalled, "it triggered the delete action");
    },
  });

  componentTest(`delete topic button - can't delete`, {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { canDeleteTopic: false });
    },
    test(assert) {
      assert.equal(
        queryAll("button.delete").length,
        0,
        `button is not displayed`
      );
    },
  });

  componentTest(
    `delete topic button - can't delete when topic author without permission`,
    {
      template: hbs`{{mount-widget widget="post" args=args}}`,
      beforeEach() {
        this.set("args", {
          canDeleteTopic: false,
          showFlagDelete: true,
          canFlag: true,
        });
      },

      async test(assert) {
        await click(".show-more-actions");

        assert.equal(
          queryAll("button.create-flag").length,
          1,
          `button is displayed`
        );
        assert.equal(
          queryAll("button.delete").length,
          1,
          `button is displayed`
        );
        assert.equal(
          queryAll("button.delete").attr("title"),
          I18n.t("post.controls.delete_topic_disallowed"),
          `shows the right button title for users without permissions`
        );
      },
    }
  );

  componentTest("recover topic button", {
    template: hbs`
      {{mount-widget widget="post" args=args recoverPost=recoverPost}}
    `,
    beforeEach() {
      this.set("args", { canRecoverTopic: true });
      this.set("recoverPost", () => (this.recovered = true));
    },
    async test(assert) {
      await click("button.recover");
      assert.ok(this.recovered);
    },
  });

  componentTest(`recover topic button - can't recover`, {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { canRecoverTopic: false });
    },
    test(assert) {
      assert.equal(
        queryAll("button.recover").length,
        0,
        `button is not displayed`
      );
    },
  });

  componentTest("delete post button", {
    template: hbs`
      {{mount-widget widget="post" args=args deletePost=deletePost}}
    `,
    beforeEach() {
      this.set("args", { canDelete: true, canFlag: true });
      this.set("deletePost", () => (this.deletePostCalled = true));
    },
    async test(assert) {
      await click(".show-more-actions");
      await click("button.delete");
      assert.ok(this.deletePostCalled, "it triggered the delete action");
    },
  });

  componentTest(`delete post button - can't delete`, {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { canDelete: false });
    },
    test(assert) {
      assert.equal(
        queryAll("button.delete").length,
        0,
        `button is not displayed`
      );
    },
  });

  componentTest(`delete post button - can't delete, can't flag`, {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", {
        canDeleteTopic: false,
        showFlagDelete: false,
        canFlag: false,
      });
    },
    test(assert) {
      assert.equal(
        queryAll("button.delete").length,
        0,
        `delete button is not displayed`
      );
      assert.equal(
        queryAll("button.create-flag").length,
        0,
        `flag button is not displayed`
      );
    },
  });

  componentTest("recover post button", {
    template: hbs`
      {{mount-widget widget="post" args=args recoverPost=recoverPost}}
    `,
    beforeEach() {
      this.set("args", { canRecover: true });
      this.set("recoverPost", () => (this.recovered = true));
    },
    async test(assert) {
      await click("button.recover");
      assert.ok(this.recovered);
    },
  });

  componentTest(`recover post button - can't recover`, {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { canRecover: false });
    },
    test(assert) {
      assert.equal(
        queryAll("button.recover").length,
        0,
        `button is not displayed`
      );
    },
  });

  componentTest(`flagging`, {
    template: hbs`
      {{mount-widget widget="post" args=args showFlags=showFlags}}
    `,
    beforeEach() {
      this.set("args", { canFlag: true });
      this.set("showFlags", () => (this.flagsShown = true));
    },
    async test(assert) {
      assert.ok(queryAll("button.create-flag").length === 1);

      await click("button.create-flag");
      assert.ok(this.flagsShown, "it triggered the action");
    },
  });

  componentTest(`flagging: can't flag`, {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { canFlag: false });
    },
    test(assert) {
      assert.ok(queryAll("button.create-flag").length === 0);
    },
  });

  componentTest(`flagging: can't flag when post is hidden`, {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { canFlag: true, hidden: true });
    },
    test(assert) {
      assert.ok(queryAll("button.create-flag").length === 0);
    },
  });

  componentTest(`read indicator`, {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { read: true });
    },
    test(assert) {
      assert.ok(queryAll(".read-state.read").length);
    },
  });

  componentTest(`unread indicator`, {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { read: false });
    },
    test(assert) {
      assert.ok(queryAll(".read-state").length);
    },
  });

  componentTest("reply directly above (supressed)", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", {
        replyToUsername: "eviltrout",
        replyToAvatarTemplate: "/images/avatar.png",
        replyDirectlyAbove: true,
      });
    },
    test(assert) {
      assert.equal(queryAll("a.reply-to-tab").length, 0, "hides the tab");
      assert.equal(
        queryAll(".avoid-tab").length,
        0,
        "doesn't have the avoid tab class"
      );
    },
  });

  componentTest("reply a few posts above (supressed)", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", {
        replyToUsername: "eviltrout",
        replyToAvatarTemplate: "/images/avatar.png",
        replyDirectlyAbove: false,
      });
    },
    test(assert) {
      assert.ok(queryAll("a.reply-to-tab").length, "shows the tab");
      assert.equal(queryAll(".avoid-tab").length, 1, "has the avoid tab class");
    },
  });

  componentTest("reply directly above", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", {
        replyToUsername: "eviltrout",
        replyToAvatarTemplate: "/images/avatar.png",
        replyDirectlyAbove: true,
      });
      this.siteSettings.suppress_reply_directly_above = false;
    },
    async test(assert) {
      assert.equal(queryAll(".avoid-tab").length, 1, "has the avoid tab class");
      await click("a.reply-to-tab");
      assert.equal(queryAll("section.embedded-posts.top .cooked").length, 1);
      assert.equal(
        queryAll("section.embedded-posts .d-icon-arrow-up").length,
        1
      );
    },
  });

  componentTest("cooked content hidden", {
    template: hbs`
      {{mount-widget widget="post" args=args expandHidden=expandHidden}}
    `,
    beforeEach() {
      this.set("args", { cooked_hidden: true });
      this.set("expandHidden", () => (this.unhidden = true));
    },
    async test(assert) {
      await click(".topic-body .expand-hidden");
      assert.ok(this.unhidden, "triggers the action");
    },
  });

  componentTest("expand first post", {
    template: hbs`{{mount-widget widget="post" model=post args=args}}`,
    beforeEach(store) {
      this.set("args", { expandablePost: true });
      this.set("post", store.createRecord("post", { id: 1234 }));
    },
    async test(assert) {
      await click(".topic-body .expand-post");
      assert.equal(queryAll(".expand-post").length, 0, "button is gone");
    },
  });

  componentTest("can't bookmark", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { canBookmark: false });
    },
    test(assert) {
      assert.equal(queryAll("button.bookmark").length, 0);
      assert.equal(queryAll("button.bookmarked").length, 0);
    },
  });

  componentTest("bookmark", {
    template: hbs`
      {{mount-widget widget="post" args=args toggleBookmark=toggleBookmark}}
    `,
    beforeEach() {
      const args = { canBookmark: true };

      this.set("args", args);
      this.set("toggleBookmark", () => (args.bookmarked = true));
    },
    async test(assert) {
      assert.equal(queryAll(".post-menu-area .bookmark").length, 1);
      assert.equal(queryAll("button.bookmarked").length, 0);
    },
  });

  componentTest("can't show admin menu when you can't manage", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { canManage: false });
    },
    test(assert) {
      assert.equal(queryAll(".post-menu-area .show-post-admin-menu").length, 0);
    },
  });

  componentTest("show admin menu", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { canManage: true });
    },
    async test(assert) {
      assert.equal(queryAll(".post-admin-menu").length, 0);
      await click(".post-menu-area .show-post-admin-menu");
      assert.equal(
        queryAll(".post-admin-menu").length,
        1,
        "it shows the popup"
      );
      await click(".post-menu-area");
      assert.equal(
        queryAll(".post-admin-menu").length,
        0,
        "clicking outside clears the popup"
      );
    },
  });

  componentTest("toggle moderator post", {
    template: hbs`
      {{mount-widget widget="post" args=args togglePostType=togglePostType}}
    `,
    beforeEach() {
      this.currentUser.set("moderator", true);
      this.set("args", { canManage: true });
      this.set("togglePostType", () => (this.toggled = true));
    },
    async test(assert) {
      await click(".post-menu-area .show-post-admin-menu");
      await click(".post-admin-menu .toggle-post-type");

      assert.ok(this.toggled);
      assert.equal(
        queryAll(".post-admin-menu").length,
        0,
        "also hides the menu"
      );
    },
  });
  componentTest("toggle moderator post", {
    template: hbs`
      {{mount-widget widget="post" args=args togglePostType=togglePostType}}
    `,
    beforeEach() {
      this.currentUser.set("moderator", true);
      this.set("args", { canManage: true });
      this.set("togglePostType", () => (this.toggled = true));
    },
    async test(assert) {
      await click(".post-menu-area .show-post-admin-menu");
      await click(".post-admin-menu .toggle-post-type");

      assert.ok(this.toggled);
      assert.equal(
        queryAll(".post-admin-menu").length,
        0,
        "also hides the menu"
      );
    },
  });

  componentTest("rebake post", {
    template: hbs`
      {{mount-widget widget="post" args=args rebakePost=rebakePost}}
    `,
    beforeEach() {
      this.set("args", { canManage: true });
      this.set("rebakePost", () => (this.baked = true));
    },
    async test(assert) {
      await click(".post-menu-area .show-post-admin-menu");
      await click(".post-admin-menu .rebuild-html");
      assert.ok(this.baked);
      assert.equal(
        queryAll(".post-admin-menu").length,
        0,
        "also hides the menu"
      );
    },
  });

  componentTest("unhide post", {
    template: hbs`
      {{mount-widget widget="post" args=args unhidePost=unhidePost}}
    `,
    beforeEach() {
      this.set("args", { canManage: true, hidden: true });
      this.set("unhidePost", () => (this.unhidden = true));
    },
    async test(assert) {
      await click(".post-menu-area .show-post-admin-menu");
      await click(".post-admin-menu .unhide-post");
      assert.ok(this.unhidden);
      assert.equal(
        queryAll(".post-admin-menu").length,
        0,
        "also hides the menu"
      );
    },
  });

  componentTest("change owner", {
    template: hbs`
      {{mount-widget widget="post" args=args changePostOwner=changePostOwner}}
    `,
    beforeEach() {
      this.currentUser.admin = true;
      this.set("args", { canManage: true });
      this.set("changePostOwner", () => (this.owned = true));
    },
    async test(assert) {
      await click(".post-menu-area .show-post-admin-menu");
      await click(".post-admin-menu .change-owner");
      assert.ok(this.owned);
      assert.equal(
        queryAll(".post-admin-menu").length,
        0,
        "also hides the menu"
      );
    },
  });

  componentTest("reply", {
    template: hbs`
      {{mount-widget widget="post" args=args replyToPost=replyToPost}}
    `,
    beforeEach() {
      this.set("args", { canCreatePost: true });
      this.set("replyToPost", () => (this.replied = true));
    },
    async test(assert) {
      await click(".post-controls .create");
      assert.ok(this.replied);
    },
  });

  componentTest("reply - without permissions", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { canCreatePost: false });
    },
    test(assert) {
      assert.equal(queryAll(".post-controls .create").length, 0);
    },
  });

  componentTest("replies - no replies", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { replyCount: 0 });
    },
    test(assert) {
      assert.equal(queryAll("button.show-replies").length, 0);
    },
  });

  componentTest("replies - multiple replies", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.siteSettings.suppress_reply_directly_below = true;
      this.set("args", { replyCount: 2, replyDirectlyBelow: true });
    },
    test(assert) {
      assert.equal(queryAll("button.show-replies").length, 1);
    },
  });

  componentTest("replies - one below, suppressed", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.siteSettings.suppress_reply_directly_below = true;
      this.set("args", { replyCount: 1, replyDirectlyBelow: true });
    },
    test(assert) {
      assert.equal(queryAll("button.show-replies").length, 0);
    },
  });

  componentTest("replies - one below, not suppressed", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.siteSettings.suppress_reply_directly_below = false;
      this.set("args", { id: 6654, replyCount: 1, replyDirectlyBelow: true });
    },
    async test(assert) {
      await click("button.show-replies");
      assert.equal(queryAll("section.embedded-posts.bottom .cooked").length, 1);
      assert.equal(
        queryAll("section.embedded-posts .d-icon-arrow-down").length,
        1
      );
    },
  });

  componentTest("topic map not shown", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { showTopicMap: false });
    },
    test(assert) {
      assert.equal(queryAll(".topic-map").length, 0);
    },
  });

  componentTest("topic map - few posts", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", {
        showTopicMap: true,
        topicPostsCount: 2,
        participants: [{ username: "eviltrout" }, { username: "codinghorror" }],
      });
    },
    async test(assert) {
      assert.equal(
        queryAll("li.avatars a.poster").length,
        0,
        "shows no participants when collapsed"
      );

      await click("nav.buttons button");
      assert.equal(
        queryAll(".topic-map-expanded a.poster").length,
        2,
        "shows all when expanded"
      );
    },
  });

  componentTest("topic map - participants", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
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
    },
    async test(assert) {
      assert.equal(
        queryAll("li.avatars a.poster").length,
        3,
        "limits to three participants"
      );

      await click("nav.buttons button");
      assert.equal(queryAll("li.avatars a.poster").length, 0);
      assert.equal(
        queryAll(".topic-map-expanded a.poster").length,
        4,
        "shows all when expanded"
      );
      assert.equal(queryAll("a.poster.toggled").length, 2, "two are toggled");
    },
  });

  componentTest("topic map - links", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
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
    },
    async test(assert) {
      assert.equal(queryAll(".topic-map").length, 1);
      assert.equal(queryAll(".map.map-collapsed").length, 1);
      assert.equal(queryAll(".topic-map-expanded").length, 0);

      await click("nav.buttons button");
      assert.equal(queryAll(".map.map-collapsed").length, 0);
      assert.equal(queryAll(".topic-map .d-icon-chevron-up").length, 1);
      assert.equal(queryAll(".topic-map-expanded").length, 1);
      assert.equal(
        queryAll(".topic-map-expanded .topic-link").length,
        5,
        "it limits the links displayed"
      );

      await click(".link-summary button");
      assert.equal(
        queryAll(".topic-map-expanded .topic-link").length,
        6,
        "all links now shown"
      );
    },
  });

  componentTest("topic map - no summary", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", { showTopicMap: true });
    },
    test(assert) {
      assert.equal(queryAll(".toggle-summary").length, 0);
    },
  });

  componentTest("topic map - has summary", {
    template: hbs`{{mount-widget widget="post" args=args showSummary=showSummary}}`,
    beforeEach() {
      this.set("args", { showTopicMap: true, hasTopicSummary: true });
      this.set("showSummary", () => (this.summaryToggled = true));
    },
    async test(assert) {
      assert.equal(queryAll(".toggle-summary").length, 1);

      await click(".toggle-summary button");
      assert.ok(this.summaryToggled);
    },
  });

  componentTest("pm map", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", {
        showTopicMap: true,
        showPMMap: true,
        allowedGroups: [],
        allowedUsers: [EmberObject.create({ username: "eviltrout" })],
      });
    },
    test(assert) {
      assert.equal(queryAll(".private-message-map").length, 1);
      assert.equal(queryAll(".private-message-map .user").length, 1);
    },
  });

  componentTest("post notice - with username", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
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
    },
    test(assert) {
      assert.equal(
        queryAll(".post-notice.returning-user:not(.old)").text().trim(),
        I18n.t("post.notice.returning_user", {
          user: "codinghorror",
          time: "2 days ago",
        })
      );
    },
  });

  componentTest("post notice - with name", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.siteSettings.display_name_on_posts = true;
      this.siteSettings.prioritize_username_in_ux = false;
      this.siteSettings.old_post_notice_days = 14;
      this.set("args", {
        username: "codinghorror",
        name: "Jeff",
        created_at: new Date(2019, 0, 1),
        notice: { type: "new_user" },
      });
    },
    test(assert) {
      assert.equal(
        queryAll(".post-notice.old.new-user").text().trim(),
        I18n.t("post.notice.new_user", { user: "Jeff", time: "Jan '10" })
      );
    },
  });

  componentTest("show group request in post", {
    template: hbs`{{mount-widget widget="post" args=args}}`,
    beforeEach() {
      this.set("args", {
        username: "foo",
        requestedGroupName: "testGroup",
      });
    },
    test(assert) {
      const link = queryAll(".group-request a");
      assert.equal(link.text().trim(), I18n.t("groups.requests.handle"));
      assert.equal(link.attr("href"), "/g/testGroup/requests?filter=foo");
    },
  });
});
