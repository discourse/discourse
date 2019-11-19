import EmberObject from "@ember/object";
import { moduleForWidget, widgetTest } from "helpers/widget-test";

moduleForWidget("post");

widgetTest("basic elements", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { shareUrl: "/example", post_number: 1 });
  },
  test(assert) {
    assert.ok(find(".names").length, "includes poster name");

    assert.ok(find("a.post-date").length, "includes post date");
    assert.ok(find("a.post-date[data-share-url]").length);
    assert.ok(find("a.post-date[data-post-number]").length);
  }
});

widgetTest("post - links", {
  template: '{{mount-widget widget="post-contents" args=args}}',
  beforeEach() {
    this.set("args", {
      cooked:
        "<a href='http://link1.example.com/'>first link</a> and <a href='http://link2.example.com/?some=query'>second link</a>",
      linkCounts: [
        { url: "http://link1.example.com/", clicks: 1, internal: true },
        { url: "http://link2.example.com/", clicks: 2, internal: true }
      ]
    });
  },
  async test(assert) {
    assert.equal(find(".badge.clicks:nth(0)").text(), "1");
    assert.equal(find(".badge.clicks:nth(1)").text(), "2");
  }
});

widgetTest("wiki", {
  template:
    '{{mount-widget widget="post" args=args showHistory=(action "showHistory")}}',
  beforeEach() {
    this.set("args", { wiki: true, version: 2, canViewEditHistory: true });
    this.on("showHistory", () => (this.historyShown = true));
  },
  async test(assert) {
    await click(".post-info .wiki");
    assert.ok(
      this.historyShown,
      "clicking the wiki icon displays the post history"
    );
  }
});

widgetTest("wiki without revision", {
  template:
    '{{mount-widget widget="post" args=args editPost=(action "editPost")}}',
  beforeEach() {
    this.set("args", { wiki: true, version: 1, canViewEditHistory: true });
    this.on("editPost", () => (this.editPostCalled = true));
  },
  async test(assert) {
    await click(".post-info .wiki");
    assert.ok(this.editPostCalled, "clicking wiki icon edits the post");
  }
});

widgetTest("via-email", {
  template:
    '{{mount-widget widget="post" args=args showRawEmail=(action "showRawEmail")}}',
  beforeEach() {
    this.set("args", { via_email: true, canViewRawEmail: true });
    this.on("showRawEmail", () => (this.rawEmailShown = true));
  },
  async test(assert) {
    await click(".post-info.via-email");
    assert.ok(this.rawEmailShown, "clicking the envelope shows the raw email");
  }
});

widgetTest("via-email without permission", {
  template:
    '{{mount-widget widget="post" args=args showRawEmail=(action "showRawEmail")}}',
  beforeEach() {
    this.set("args", { via_email: true, canViewRawEmail: false });
    this.on("showRawEmail", () => (this.rawEmailShown = true));
  },
  async test(assert) {
    await click(".post-info.via-email");
    assert.ok(
      !this.rawEmailShown,
      "clicking the envelope doesn't show the raw email"
    );
  }
});

widgetTest("history", {
  template:
    '{{mount-widget widget="post" args=args showHistory=(action "showHistory")}}',
  beforeEach() {
    this.set("args", { version: 3, canViewEditHistory: true });
    this.on("showHistory", () => (this.historyShown = true));
  },
  async test(assert) {
    await click(".post-info.edits");
    assert.ok(this.historyShown, "clicking the pencil shows the history");
  }
});

widgetTest("history without view permission", {
  template:
    '{{mount-widget widget="post" args=args showHistory=(action "showHistory")}}',
  beforeEach() {
    this.set("args", { version: 3, canViewEditHistory: false });
    this.on("showHistory", () => (this.historyShown = true));
  },
  async test(assert) {
    await click(".post-info.edits");
    assert.ok(
      !this.historyShown,
      `clicking the pencil doesn't show the history`
    );
  }
});

widgetTest("whisper", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { isWhisper: true });
  },
  test(assert) {
    assert.ok(find(".topic-post.whisper").length === 1);
    assert.ok(find(".post-info.whisper").length === 1);
  }
});

widgetTest("like count button", {
  template: '{{mount-widget widget="post" model=post args=args}}',
  beforeEach(store) {
    const topic = store.createRecord("topic", { id: 123 });
    const post = store.createRecord("post", {
      id: 1,
      post_number: 1,
      topic,
      like_count: 3,
      actions_summary: [{ id: 2, count: 1, hidden: false, can_act: true }]
    });
    this.set("post", post);
    this.set("args", { likeCount: 1 });
  },
  async test(assert) {
    assert.ok(find("button.like-count").length === 1);
    assert.ok(find(".who-liked").length === 0);

    // toggle it on
    await click("button.like-count");
    assert.ok(find(".who-liked").length === 1);
    assert.ok(find(".who-liked a.trigger-user-card").length === 1);

    // toggle it off
    await click("button.like-count");
    assert.ok(find(".who-liked").length === 0);
    assert.ok(find(".who-liked a.trigger-user-card").length === 0);
  }
});

widgetTest(`like count with no likes`, {
  template: '{{mount-widget widget="post" model=post args=args}}',
  beforeEach() {
    this.set("args", { likeCount: 0 });
  },
  test(assert) {
    assert.ok(find("button.like-count").length === 0);
  }
});

widgetTest("share button", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { shareUrl: "http://share-me.example.com" });
  },
  test(assert) {
    assert.ok(
      !!find(".actions button[data-share-url]").length,
      "it renders a share button"
    );
  }
});

widgetTest("liking", {
  template:
    '{{mount-widget widget="post-menu" args=args toggleLike=(action "toggleLike")}}',
  beforeEach() {
    const args = { showLike: true, canToggleLike: true };
    this.set("args", args);
    this.on("toggleLike", () => {
      args.liked = !args.liked;
      args.likeCount = args.liked ? 1 : 0;
    });
  },
  async test(assert) {
    assert.ok(!!find(".actions button.like").length);
    assert.ok(find(".actions button.like-count").length === 0);

    await click(".actions button.like");
    assert.ok(!find(".actions button.like").length);
    assert.ok(!!find(".actions button.has-like").length);
    assert.ok(find(".actions button.like-count").length === 1);

    await click(".actions button.has-like");
    assert.ok(!!find(".actions button.like").length);
    assert.ok(!find(".actions button.has-like").length);
    assert.ok(find(".actions button.like-count").length === 0);
  }
});

widgetTest("anon liking", {
  template:
    '{{mount-widget widget="post-menu" args=args showLogin=(action "showLogin")}}',
  anonymous: true,
  beforeEach() {
    const args = { showLike: true };
    this.set("args", args);
    this.on("showLogin", () => (this.loginShown = true));
  },
  async test(assert) {
    assert.ok(!!find(".actions button.like").length);
    assert.ok(find(".actions button.like-count").length === 0);

    assert.equal(
      find("button.like").attr("title"),
      I18n.t("post.controls.like"),
      `shows the right button title for anonymous users`
    );

    await click(".actions button.like");
    assert.ok(this.loginShown);
  }
});

widgetTest("edit button", {
  template:
    '{{mount-widget widget="post" args=args editPost=(action "editPost")}}',
  beforeEach() {
    this.set("args", { canEdit: true });
    this.on("editPost", () => (this.editPostCalled = true));
  },
  async test(assert) {
    await click("button.edit");
    assert.ok(this.editPostCalled, "it triggered the edit action");
  }
});

widgetTest(`edit button - can't edit`, {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { canEdit: false });
  },
  test(assert) {
    assert.equal(find("button.edit").length, 0, `button is not displayed`);
  }
});

widgetTest("recover button", {
  template:
    '{{mount-widget widget="post" args=args deletePost=(action "deletePost")}}',
  beforeEach() {
    this.set("args", { canDelete: true });
    this.on("deletePost", () => (this.deletePostCalled = true));
  },
  async test(assert) {
    await click("button.delete");
    assert.ok(this.deletePostCalled, "it triggered the delete action");
  }
});

widgetTest("delete topic button", {
  template:
    '{{mount-widget widget="post" args=args deletePost=(action "deletePost")}}',
  beforeEach() {
    this.set("args", { canDeleteTopic: true });
    this.on("deletePost", () => (this.deletePostCalled = true));
  },
  async test(assert) {
    await click("button.delete");
    assert.ok(this.deletePostCalled, "it triggered the delete action");
  }
});

widgetTest(`delete topic button - can't delete`, {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { canDeleteTopic: false });
  },
  test(assert) {
    assert.equal(find("button.delete").length, 0, `button is not displayed`);
  }
});

widgetTest(
  `delete topic button - can't delete when topic author without permission`,
  {
    template: '{{mount-widget widget="post" args=args}}',
    beforeEach() {
      this.set("args", {
        canDeleteTopic: false,
        showFlagDelete: true
      });
    },

    test(assert) {
      assert.equal(find("button.delete").length, 1, `button is displayed`);
      assert.equal(
        find("button.delete").attr("title"),
        I18n.t("post.controls.delete_topic_disallowed"),
        `shows the right button title for users without permissions`
      );
    }
  }
);

widgetTest("recover topic button", {
  template:
    '{{mount-widget widget="post" args=args recoverPost=(action "recoverPost")}}',
  beforeEach() {
    this.set("args", { canRecoverTopic: true });
    this.on("recoverPost", () => (this.recovered = true));
  },
  async test(assert) {
    await click("button.recover");
    assert.ok(this.recovered);
  }
});

widgetTest(`recover topic button - can't recover`, {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { canRecoverTopic: false });
  },
  test(assert) {
    assert.equal(find("button.recover").length, 0, `button is not displayed`);
  }
});

widgetTest("delete post button", {
  template:
    '{{mount-widget widget="post" args=args deletePost=(action "deletePost")}}',
  beforeEach() {
    this.set("args", { canDelete: true });
    this.on("deletePost", () => (this.deletePostCalled = true));
  },
  async test(assert) {
    await click("button.delete");
    assert.ok(this.deletePostCalled, "it triggered the delete action");
  }
});

widgetTest(`delete post button - can't delete`, {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { canDelete: false });
  },
  test(assert) {
    assert.equal(find("button.delete").length, 0, `button is not displayed`);
  }
});

widgetTest("recover post button", {
  template:
    '{{mount-widget widget="post" args=args recoverPost=(action "recoverPost")}}',
  beforeEach() {
    this.set("args", { canRecover: true });
    this.on("recoverPost", () => (this.recovered = true));
  },
  async test(assert) {
    await click("button.recover");
    assert.ok(this.recovered);
  }
});

widgetTest(`recover post button - can't recover`, {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { canRecover: false });
  },
  test(assert) {
    assert.equal(find("button.recover").length, 0, `button is not displayed`);
  }
});

widgetTest(`flagging`, {
  template:
    '{{mount-widget widget="post" args=args showFlags=(action "showFlags")}}',
  beforeEach() {
    this.set("args", { canFlag: true });
    this.on("showFlags", () => (this.flagsShown = true));
  },
  async test(assert) {
    assert.ok(find("button.create-flag").length === 1);

    await click("button.create-flag");
    assert.ok(this.flagsShown, "it triggered the action");
  }
});

widgetTest(`flagging: can't flag`, {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { canFlag: false });
  },
  test(assert) {
    assert.ok(find("button.create-flag").length === 0);
  }
});

widgetTest(`flagging: can't flag when post is hidden`, {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { canFlag: true, hidden: true });
  },
  test(assert) {
    assert.ok(find("button.create-flag").length === 0);
  }
});

widgetTest(`read indicator`, {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { read: true });
  },
  test(assert) {
    assert.ok(find(".read-state.read").length);
  }
});

widgetTest(`unread indicator`, {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { read: false });
  },
  test(assert) {
    assert.ok(find(".read-state").length);
  }
});

widgetTest("reply directly above (supressed)", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", {
      replyToUsername: "eviltrout",
      replyToAvatarTemplate: "/images/avatar.png",
      replyDirectlyAbove: true
    });
  },
  test(assert) {
    assert.equal(find("a.reply-to-tab").length, 0, "hides the tab");
    assert.equal(
      find(".avoid-tab").length,
      0,
      "doesn't have the avoid tab class"
    );
  }
});

widgetTest("reply a few posts above (supressed)", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", {
      replyToUsername: "eviltrout",
      replyToAvatarTemplate: "/images/avatar.png",
      replyDirectlyAbove: false
    });
  },
  test(assert) {
    assert.ok(find("a.reply-to-tab").length, "shows the tab");
    assert.equal(find(".avoid-tab").length, 1, "has the avoid tab class");
  }
});

widgetTest("reply directly above", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", {
      replyToUsername: "eviltrout",
      replyToAvatarTemplate: "/images/avatar.png",
      replyDirectlyAbove: true
    });
    this.siteSettings.suppress_reply_directly_above = false;
  },
  async test(assert) {
    assert.equal(find(".avoid-tab").length, 1, "has the avoid tab class");
    await click("a.reply-to-tab");
    assert.equal(find("section.embedded-posts.top .cooked").length, 1);
    assert.equal(find("section.embedded-posts .d-icon-arrow-up").length, 1);
  }
});

widgetTest("cooked content hidden", {
  template:
    '{{mount-widget widget="post" args=args expandHidden=(action "expandHidden")}}',
  beforeEach() {
    this.set("args", { cooked_hidden: true });
    this.on("expandHidden", () => (this.unhidden = true));
  },
  async test(assert) {
    await click(".topic-body .expand-hidden");
    assert.ok(this.unhidden, "triggers the action");
  }
});

widgetTest("expand first post", {
  template: '{{mount-widget widget="post" model=post args=args}}',
  beforeEach(store) {
    this.set("args", { expandablePost: true });
    this.set("post", store.createRecord("post", { id: 1234 }));
  },
  async test(assert) {
    await click(".topic-body .expand-post");
    assert.equal(find(".expand-post").length, 0, "button is gone");
  }
});

widgetTest("can't bookmark", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { canBookmark: false });
  },
  test(assert) {
    assert.equal(find("button.bookmark").length, 0);
    assert.equal(find("button.bookmarked").length, 0);
  }
});

widgetTest("bookmark", {
  template:
    '{{mount-widget widget="post" args=args toggleBookmark=(action "toggleBookmark")}}',
  beforeEach() {
    const args = { canBookmark: true };

    this.set("args", args);
    this.on("toggleBookmark", () => (args.bookmarked = true));
  },
  async test(assert) {
    assert.equal(find(".post-menu-area .bookmark").length, 1);
    assert.equal(find("button.bookmarked").length, 0);

    await click("button.bookmark");
    assert.equal(find("button.bookmarked").length, 1);
  }
});

widgetTest("can't show admin menu when you can't manage", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { canManage: false });
  },
  test(assert) {
    assert.equal(find(".post-menu-area .show-post-admin-menu").length, 0);
  }
});

widgetTest("show admin menu", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { canManage: true });
  },
  async test(assert) {
    assert.equal(find(".post-admin-menu").length, 0);
    await click(".post-menu-area .show-post-admin-menu");
    assert.equal(find(".post-admin-menu").length, 1, "it shows the popup");
    await click(".post-menu-area");
    assert.equal(
      find(".post-admin-menu").length,
      0,
      "clicking outside clears the popup"
    );
  }
});

widgetTest("toggle moderator post", {
  template:
    '{{mount-widget widget="post" args=args togglePostType=(action "togglePostType")}}',
  beforeEach() {
    this.currentUser.set("moderator", true);
    this.set("args", { canManage: true });
    this.on("togglePostType", () => (this.toggled = true));
  },
  async test(assert) {
    await click(".post-menu-area .show-post-admin-menu");
    await click(".post-admin-menu .toggle-post-type");

    assert.ok(this.toggled);
    assert.equal(find(".post-admin-menu").length, 0, "also hides the menu");
  }
});
widgetTest("toggle moderator post", {
  template:
    '{{mount-widget widget="post" args=args togglePostType=(action "togglePostType")}}',
  beforeEach() {
    this.currentUser.set("moderator", true);
    this.set("args", { canManage: true });
    this.on("togglePostType", () => (this.toggled = true));
  },
  async test(assert) {
    await click(".post-menu-area .show-post-admin-menu");
    await click(".post-admin-menu .toggle-post-type");

    assert.ok(this.toggled);
    assert.equal(find(".post-admin-menu").length, 0, "also hides the menu");
  }
});

widgetTest("rebake post", {
  template:
    '{{mount-widget widget="post" args=args rebakePost=(action "rebakePost")}}',
  beforeEach() {
    this.set("args", { canManage: true });
    this.on("rebakePost", () => (this.baked = true));
  },
  async test(assert) {
    await click(".post-menu-area .show-post-admin-menu");
    await click(".post-admin-menu .rebuild-html");
    assert.ok(this.baked);
    assert.equal(find(".post-admin-menu").length, 0, "also hides the menu");
  }
});

widgetTest("unhide post", {
  template:
    '{{mount-widget widget="post" args=args unhidePost=(action "unhidePost")}}',
  beforeEach() {
    this.set("args", { canManage: true, hidden: true });
    this.on("unhidePost", () => (this.unhidden = true));
  },
  async test(assert) {
    await click(".post-menu-area .show-post-admin-menu");
    await click(".post-admin-menu .unhide-post");
    assert.ok(this.unhidden);
    assert.equal(find(".post-admin-menu").length, 0, "also hides the menu");
  }
});

widgetTest("change owner", {
  template:
    '{{mount-widget widget="post" args=args changePostOwner=(action "changePostOwner")}}',
  beforeEach() {
    this.currentUser.admin = true;
    this.set("args", { canManage: true });
    this.on("changePostOwner", () => (this.owned = true));
  },
  async test(assert) {
    await click(".post-menu-area .show-post-admin-menu");
    await click(".post-admin-menu .change-owner");
    assert.ok(this.owned);
    assert.equal(find(".post-admin-menu").length, 0, "also hides the menu");
  }
});

widgetTest("reply", {
  template:
    '{{mount-widget widget="post" args=args replyToPost=(action "replyToPost")}}',
  beforeEach() {
    this.set("args", { canCreatePost: true });
    this.on("replyToPost", () => (this.replied = true));
  },
  async test(assert) {
    await click(".post-controls .create");
    assert.ok(this.replied);
  }
});

widgetTest("reply - without permissions", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { canCreatePost: false });
  },
  test(assert) {
    assert.equal(find(".post-controls .create").length, 0);
  }
});

widgetTest("replies - no replies", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { replyCount: 0 });
  },
  test(assert) {
    assert.equal(find("button.show-replies").length, 0);
  }
});

widgetTest("replies - multiple replies", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.siteSettings.suppress_reply_directly_below = true;
    this.set("args", { replyCount: 2, replyDirectlyBelow: true });
  },
  test(assert) {
    assert.equal(find("button.show-replies").length, 1);
  }
});

widgetTest("replies - one below, suppressed", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.siteSettings.suppress_reply_directly_below = true;
    this.set("args", { replyCount: 1, replyDirectlyBelow: true });
  },
  test(assert) {
    assert.equal(find("button.show-replies").length, 0);
  }
});

widgetTest("replies - one below, not suppressed", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.siteSettings.suppress_reply_directly_below = false;
    this.set("args", { id: 6654, replyCount: 1, replyDirectlyBelow: true });
  },
  async test(assert) {
    await click("button.show-replies");
    assert.equal(find("section.embedded-posts.bottom .cooked").length, 1);
    assert.equal(find("section.embedded-posts .d-icon-arrow-down").length, 1);
  }
});

widgetTest("topic map not shown", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { showTopicMap: false });
  },
  test(assert) {
    assert.equal(find(".topic-map").length, 0);
  }
});

widgetTest("topic map - few posts", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", {
      showTopicMap: true,
      topicPostsCount: 2,
      participants: [{ username: "eviltrout" }, { username: "codinghorror" }]
    });
  },
  async test(assert) {
    assert.equal(
      find("li.avatars a.poster").length,
      0,
      "shows no participants when collapsed"
    );

    await click("nav.buttons button");
    assert.equal(
      find(".topic-map-expanded a.poster").length,
      2,
      "shows all when expanded"
    );
  }
});

widgetTest("topic map - participants", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", {
      showTopicMap: true,
      topicPostsCount: 10,
      participants: [
        { username: "eviltrout" },
        { username: "codinghorror" },
        { username: "sam" },
        { username: "ZogStrIP" }
      ],
      userFilters: ["sam", "codinghorror"]
    });
  },
  async test(assert) {
    assert.equal(
      find("li.avatars a.poster").length,
      3,
      "limits to three participants"
    );

    await click("nav.buttons button");
    assert.equal(find("li.avatars a.poster").length, 0);
    assert.equal(
      find(".topic-map-expanded a.poster").length,
      4,
      "shows all when expanded"
    );
    assert.equal(find("a.poster.toggled").length, 2, "two are toggled");
  }
});

widgetTest("topic map - links", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", {
      showTopicMap: true,
      topicLinks: [
        { url: "http://link1.example.com", clicks: 0 },
        { url: "http://link2.example.com", clicks: 0 },
        { url: "http://link3.example.com", clicks: 0 },
        { url: "http://link4.example.com", clicks: 0 },
        { url: "http://link5.example.com", clicks: 0 },
        { url: "http://link6.example.com", clicks: 0 }
      ]
    });
  },
  async test(assert) {
    assert.equal(find(".topic-map").length, 1);
    assert.equal(find(".map.map-collapsed").length, 1);
    assert.equal(find(".topic-map-expanded").length, 0);

    await click("nav.buttons button");
    assert.equal(find(".map.map-collapsed").length, 0);
    assert.equal(find(".topic-map .d-icon-chevron-up").length, 1);
    assert.equal(find(".topic-map-expanded").length, 1);
    assert.equal(
      find(".topic-map-expanded .topic-link").length,
      5,
      "it limits the links displayed"
    );

    await click(".link-summary button");
    assert.equal(
      find(".topic-map-expanded .topic-link").length,
      6,
      "all links now shown"
    );
  }
});

widgetTest("topic map - no summary", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", { showTopicMap: true });
  },
  test(assert) {
    assert.equal(find(".toggle-summary").length, 0);
  }
});

widgetTest("topic map - has summary", {
  template:
    '{{mount-widget widget="post" args=args toggleSummary=(action "toggleSummary")}}',
  beforeEach() {
    this.set("args", { showTopicMap: true, hasTopicSummary: true });
    this.on("toggleSummary", () => (this.summaryToggled = true));
  },
  async test(assert) {
    assert.equal(find(".toggle-summary").length, 1);

    await click(".toggle-summary button");
    assert.ok(this.summaryToggled);
  }
});

widgetTest("pm map", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.set("args", {
      showTopicMap: true,
      showPMMap: true,
      allowedGroups: [],
      allowedUsers: [EmberObject.create({ username: "eviltrout" })]
    });
  },
  test(assert) {
    assert.equal(find(".private-message-map").length, 1);
    assert.equal(find(".private-message-map .user").length, 1);
  }
});

widgetTest("post notice - with username", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    const twoDaysAgo = new Date();
    twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);
    this.siteSettings.display_name_on_posts = false;
    this.siteSettings.prioritize_username_in_ux = true;
    this.siteSettings.old_post_notice_days = 14;
    this.set("args", {
      noticeType: "returning_user",
      noticeTime: twoDaysAgo,
      username: "codinghorror",
      name: "Jeff",
      created_at: new Date()
    });
  },
  test(assert) {
    assert.equal(
      find(".post-notice.returning-user:not(.old)")
        .text()
        .trim(),
      I18n.t("post.notice.returning_user", {
        user: "codinghorror",
        time: "2 days ago"
      })
    );
  }
});

widgetTest("post notice - with name", {
  template: '{{mount-widget widget="post" args=args}}',
  beforeEach() {
    this.siteSettings.display_name_on_posts = true;
    this.siteSettings.prioritize_username_in_ux = false;
    this.siteSettings.old_post_notice_days = 14;
    this.set("args", {
      noticeType: "new_user",
      username: "codinghorror",
      name: "Jeff",
      created_at: new Date(2019, 0, 1)
    });
  },
  test(assert) {
    assert.equal(
      find(".post-notice.old.new-user")
        .text()
        .trim(),
      I18n.t("post.notice.new_user", { user: "Jeff", time: "Jan '10" })
    );
  }
});
