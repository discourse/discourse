import { moduleForWidget, widgetTest } from 'helpers/widget-test';

moduleForWidget('post');

widgetTest('basic elements', {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', { shareUrl: '/example', post_number: 1 });
  },
  test(assert) {
    assert.ok(this.$('.names').length, 'includes poster name');

    assert.ok(this.$('a.post-date').length, 'includes post date');
    assert.ok(this.$('a.post-date[data-share-url]').length);
    assert.ok(this.$('a.post-date[data-post-number]').length);
  }
});

widgetTest('wiki', {
  template: '{{mount-widget widget="post" args=args editPost="editPost"}}',
  setup() {
    this.set('args', { wiki: true });
    this.on('editPost', () => this.editPostCalled = true);
  },
  test(assert) {
    click('.post-info.wiki');
    andThen(() => {
      assert.ok(this.editPostCalled, 'clicking the wiki icon edits the post');
    });
  }
});

widgetTest('via-email', {
  template: '{{mount-widget widget="post" args=args showRawEmail="showRawEmail"}}',
  setup() {
    this.set('args', { via_email: true, canViewRawEmail: true });
    this.on('showRawEmail', () => this.rawEmailShown = true);
  },
  test(assert) {
    click('.post-info.via-email');
    andThen(() => {
      assert.ok(this.rawEmailShown, 'clicking the enveloppe shows the raw email');
    });
  }
});

widgetTest('via-email without permission', {
  template: '{{mount-widget widget="post" args=args showRawEmail="showRawEmail"}}',
  setup() {
    this.set('args', { via_email: true, canViewRawEmail: false });
    this.on('showRawEmail', () => this.rawEmailShown = true);
  },
  test(assert) {
    click('.post-info.via-email');
    andThen(() => {
      assert.ok(!this.rawEmailShown, `clicking the enveloppe doesn't show the raw email`);
    });
  }
});

widgetTest('history', {
  template: '{{mount-widget widget="post" args=args showHistory="showHistory"}}',
  setup() {
    this.set('args', { version: 3, canViewEditHistory: true });
    this.on('showHistory', () => this.historyShown = true);
  },
  test(assert) {
    click('.post-info.edits');
    andThen(() => {
      assert.ok(this.historyShown, 'clicking the pencil shows the history');
    });
  }
});

widgetTest('history without view permission', {
  template: '{{mount-widget widget="post" args=args showHistory="showHistory"}}',
  setup() {
    this.set('args', { version: 3, canViewEditHistory: false });
    this.on('showHistory', () => this.historyShown = true);
  },
  test(assert) {
    click('.post-info.edits');
    andThen(() => {
      assert.ok(!this.historyShown, `clicking the pencil doesn't show the history`);
    });
  }
});

widgetTest('whisper', {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', { isWhisper: true });
  },
  test(assert) {
    assert.ok(this.$('.topic-post.whisper').length === 1);
    assert.ok(this.$('.post-info.whisper').length === 1);
  }
});

widgetTest('like count button', {
  template: '{{mount-widget widget="post" model=post args=args}}',
  setup(store) {
    const topic = store.createRecord('topic', {id: 123});
    const post = store.createRecord('post', {
      id: 1,
      post_number: 1,
      topic,
      like_count: 3,
      actions_summary: [ {id: 2, count: 1, hidden: false, can_act: true} ]
    });
    this.set('post', post);
    this.set('args', { likeCount: 1 });
  },
  test(assert) {
    assert.ok(this.$('button.like-count').length === 1);
    assert.ok(this.$('.who-liked').length === 0);

    // toggle it on
    click('button.like-count');
    andThen(() => {
      assert.ok(this.$('.who-liked').length === 1);
      assert.ok(this.$('.who-liked a.trigger-user-card').length === 1);
    });

    // toggle it off
    click('button.like-count');
    andThen(() => {
      assert.ok(this.$('.who-liked').length === 0);
      assert.ok(this.$('.who-liked a.trigger-user-card').length === 0);
    });
  }
});

widgetTest(`like count with no likes`, {
  template: '{{mount-widget widget="post" model=post args=args}}',
  setup() {
    this.set('args', { likeCount: 0 });
  },
  test(assert) {
    assert.ok(this.$('button.like-count').length === 0);
  }
});

widgetTest('share button', {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', { shareUrl: 'http://share-me.example.com' });
  },
  test(assert) {
    assert.ok(!!this.$('.actions button[data-share-url]').length, 'it renders a share button');
  }
});

widgetTest('liking', {
  template: '{{mount-widget widget="post-menu" args=args toggleLike="toggleLike"}}',
  setup() {
    const args = { showLike: true, canToggleLike: true };
    this.set('args', args);
    this.on('toggleLike', () => {
      args.liked = !args.liked;
      args.likeCount = args.liked ? 1 : 0;
    });
  },
  test(assert) {
    assert.ok(!!this.$('.actions button.like').length);
    assert.ok(this.$('.actions button.like-count').length === 0);

    click('.actions button.like');
    andThen(() => {
      assert.ok(!this.$('.actions button.like').length);
      assert.ok(!!this.$('.actions button.has-like').length);
      assert.ok(this.$('.actions button.like-count').length === 1);
    });

    click('.actions button.has-like');
    andThen(() => {
      assert.ok(!!this.$('.actions button.like').length);
      assert.ok(!this.$('.actions button.has-like').length);
      assert.ok(this.$('.actions button.like-count').length === 0);
    });
  }
});

widgetTest('edit button', {
  template: '{{mount-widget widget="post" args=args editPost="editPost"}}',
  setup() {
    this.set('args', { canEdit: true });
    this.on('editPost', () => this.editPostCalled = true);
  },
  test(assert) {
    click('button.edit');
    andThen(() => {
      assert.ok(this.editPostCalled, 'it triggered the edit action');
    });
  }
});

widgetTest(`edit button - can't edit`, {
  template: '{{mount-widget widget="post" args=args editPost="editPost"}}',
  setup() {
    this.set('args', { canEdit: false });
  },
  test(assert) {
    assert.equal(this.$('button.edit').length, 0, `button is not displayed`);
  }
});

widgetTest('recover button', {
  template: '{{mount-widget widget="post" args=args deletePost="deletePost"}}',
  setup() {
    this.set('args', { canDelete: true });
    this.on('deletePost', () => this.deletePostCalled = true);
  },
  test(assert) {
    click('button.delete');
    andThen(() => {
      assert.ok(this.deletePostCalled, 'it triggered the delete action');
    });
  }
});

widgetTest('delete topic button', {
  template: '{{mount-widget widget="post" args=args deletePost="deletePost"}}',
  setup() {
    this.set('args', { canDeleteTopic: true });
    this.on('deletePost', () => this.deletePostCalled = true);
  },
  test(assert) {
    click('button.delete');
    andThen(() => {
      assert.ok(this.deletePostCalled, 'it triggered the delete action');
    });
  }
});

widgetTest(`delete topic button - can't delete`, {
  template: '{{mount-widget widget="post" args=args deletePost="deletePost"}}',
  setup() {
    this.set('args', { canDeleteTopic: false });
  },
  test(assert) {
    assert.equal(this.$('button.delete').length, 0, `button is not displayed`);
  }
});

widgetTest('recover topic button', {
  template: '{{mount-widget widget="post" args=args recoverPost="recoverPost"}}',
  setup() {
    this.set('args', { canRecoverTopic: true });
    this.on('recoverPost', () => this.recovered = true);
  },
  test(assert) {
    click('button.recover');
    andThen(() => assert.ok(this.recovered));
  }
});

widgetTest(`recover topic button - can't recover`, {
  template: '{{mount-widget widget="post" args=args deletePost="deletePost"}}',
  setup() {
    this.set('args', { canRecoverTopic: false });
  },
  test(assert) {
    assert.equal(this.$('button.recover').length, 0, `button is not displayed`);
  }
});

widgetTest('delete post button', {
  template: '{{mount-widget widget="post" args=args deletePost="deletePost"}}',
  setup() {
    this.set('args', { canDelete: true });
    this.on('deletePost', () => this.deletePostCalled = true);
  },
  test(assert) {
    click('button.delete');
    andThen(() => {
      assert.ok(this.deletePostCalled, 'it triggered the delete action');
    });
  }
});

widgetTest(`delete post button - can't delete`, {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', { canDelete: false });
  },
  test(assert) {
    assert.equal(this.$('button.delete').length, 0, `button is not displayed`);
  }
});

widgetTest('recover post button', {
  template: '{{mount-widget widget="post" args=args recoverPost="recoverPost"}}',
  setup() {
    this.set('args', { canRecover: true });
    this.on('recoverPost', () => this.recovered = true);
  },
  test(assert) {
    click('button.recover');
    andThen(() => assert.ok(this.recovered));
  }
});

widgetTest(`recover post button - can't recover`, {
  template: '{{mount-widget widget="post" args=args deletePost="deletePost"}}',
  setup() {
    this.set('args', { canRecover: false });
  },
  test(assert) {
    assert.equal(this.$('button.recover').length, 0, `button is not displayed`);
  }
});

widgetTest(`flagging`, {
  template: '{{mount-widget widget="post" args=args showFlags="showFlags"}}',
  setup() {
    this.set('args', { canFlag: true });
    this.on('showFlags', () => this.flagsShown = true);
  },
  test(assert) {
    assert.ok(this.$('button.create-flag').length === 1);

    click('button.create-flag');
    andThen(() => {
      assert.ok(this.flagsShown, 'it triggered the action');
    });
  }
});

widgetTest(`flagging: can't flag`, {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', { canFlag: false });
  },
  test(assert) {
    assert.ok(this.$('button.create-flag').length === 0);
  }
});

widgetTest(`read indicator`, {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', { read: true });
  },
  test(assert) {
    assert.ok(this.$('.read-state.read').length);
  }
});

widgetTest(`unread indicator`, {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', { read: false });
  },
  test(assert) {
    assert.ok(this.$('.read-state').length);
  }
});

widgetTest("reply directly above (supressed)", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', {
      replyToUsername: 'eviltrout',
      replyToAvatarTemplate: '/images/avatar.png',
      replyDirectlyAbove: true
    });
  },
  test(assert) {
    assert.equal(this.$('a.reply-to-tab').length, 0, 'hides the tab');
    assert.equal(this.$('.avoid-tab').length, 0, "doesn't have the avoid tab class");
  }
});

widgetTest("reply a few posts above (supressed)", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', {
      replyToUsername: 'eviltrout',
      replyToAvatarTemplate: '/images/avatar.png',
      replyDirectlyAbove: false
    });
  },
  test(assert) {
    assert.ok(this.$('a.reply-to-tab').length, 'shows the tab');
    assert.equal(this.$('.avoid-tab').length, 1, "has the avoid tab class");
  }
});

widgetTest("reply directly above", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', {
      replyToUsername: 'eviltrout',
      replyToAvatarTemplate: '/images/avatar.png',
      replyDirectlyAbove: true
    });
    this.siteSettings.suppress_reply_directly_above = false;
  },
  test(assert) {
    assert.equal(this.$('.avoid-tab').length, 1, "has the avoid tab class");
    click('a.reply-to-tab');
    andThen(() => {
      assert.equal(this.$('section.embedded-posts.top .cooked').length, 1);
      assert.equal(this.$('section.embedded-posts i.fa-arrow-up').length, 1);
    });
  }
});

widgetTest("cooked content hidden", {
  template: '{{mount-widget widget="post" args=args expandHidden="expandHidden"}}',
  setup() {
    this.set('args', { cooked_hidden: true });
    this.on('expandHidden', () => this.unhidden = true);
  },
  test(assert) {
    click('.topic-body .expand-hidden');
    andThen(() => {
      assert.ok(this.unhidden, 'triggers the action');
    });
  }
});

widgetTest("expand first post", {
  template: '{{mount-widget widget="post" model=post args=args}}',
  setup(store) {
    this.set('args', { expandablePost: true });
    this.set('post', store.createRecord('post', { id: 1234 }));
  },
  test(assert) {
    click('.topic-body .expand-post');
    andThen(() => {
      assert.equal(this.$('.expand-post').length, 0, 'button is gone');
    });
  }
});

widgetTest("can't bookmark", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', { canBookmark: false });
  },
  test(assert) {
    assert.equal(this.$('button.bookmark').length, 0);
    assert.equal(this.$('button.bookmarked').length, 0);
  }
});

widgetTest("bookmark", {
  template: '{{mount-widget widget="post" args=args toggleBookmark="toggleBookmark"}}',
  setup() {
    const args = { canBookmark: true };

    this.set('args', args);
    this.on('toggleBookmark', () => args.bookmarked = true);
  },
  test(assert) {
    assert.equal(this.$('.post-menu-area .bookmark').length, 1);
    assert.equal(this.$('button.bookmarked').length, 0);

    click('button.bookmark');
    andThen(() => {
      assert.equal(this.$('button.bookmarked').length, 1);
    });
  }
});

widgetTest("can't show admin menu when you can't manage", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', { canManage: false });
  },
  test(assert) {
    assert.equal(this.$('.post-menu-area .show-post-admin-menu').length, 0);
  }
});

widgetTest("show admin menu", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', { canManage: true });
  },
  test(assert) {
    assert.equal(this.$('.post-admin-menu').length, 0);
    click('.post-menu-area .show-post-admin-menu');
    andThen(() => {
      assert.equal(this.$('.post-admin-menu').length, 1, 'it shows the popup');
    });
    click('.post-menu-area');
    andThen(() => {
      assert.equal(this.$('.post-admin-menu').length, 0, 'clicking outside clears the popup');
    });
  }
});

widgetTest("toggle moderator post", {
  template: '{{mount-widget widget="post" args=args togglePostType="togglePostType"}}',
  setup() {
    this.set('args', { canManage: true });
    this.on('togglePostType', () => this.toggled = true);
  },
  test(assert) {
    click('.post-menu-area .show-post-admin-menu');
    click('.post-admin-menu .toggle-post-type');
    andThen(() => {
      assert.ok(this.toggled);
      assert.equal(this.$('.post-admin-menu').length, 0, 'also hides the menu');
    });
  }
});
widgetTest("toggle moderator post", {
  template: '{{mount-widget widget="post" args=args togglePostType="togglePostType"}}',
  setup() {
    this.set('args', { canManage: true });
    this.on('togglePostType', () => this.toggled = true);
  },
  test(assert) {
    click('.post-menu-area .show-post-admin-menu');
    click('.post-admin-menu .toggle-post-type');
    andThen(() => {
      assert.ok(this.toggled);
      assert.equal(this.$('.post-admin-menu').length, 0, 'also hides the menu');
    });
  }
});

widgetTest("rebake post", {
  template: '{{mount-widget widget="post" args=args rebakePost="rebakePost"}}',
  setup() {
    this.set('args', { canManage: true });
    this.on('rebakePost', () => this.baked = true);
  },
  test(assert) {
    click('.post-menu-area .show-post-admin-menu');
    click('.post-admin-menu .rebuild-html');
    andThen(() => {
      assert.ok(this.baked);
      assert.equal(this.$('.post-admin-menu').length, 0, 'also hides the menu');
    });
  }
});

widgetTest("unhide post", {
  template: '{{mount-widget widget="post" args=args unhidePost="unhidePost"}}',
  setup() {
    this.set('args', { canManage: true, hidden: true });
    this.on('unhidePost', () => this.unhidden = true);
  },
  test(assert) {
    click('.post-menu-area .show-post-admin-menu');
    click('.post-admin-menu .unhide-post');
    andThen(() => {
      assert.ok(this.unhidden);
      assert.equal(this.$('.post-admin-menu').length, 0, 'also hides the menu');
    });
  }
});

widgetTest("change owner", {
  template: '{{mount-widget widget="post" args=args changePostOwner="changePostOwner"}}',
  setup() {
    this.currentUser.admin = true;
    this.set('args', { canManage: true });
    this.on('changePostOwner', () => this.owned = true);
  },
  test(assert) {
    click('.post-menu-area .show-post-admin-menu');
    click('.post-admin-menu .change-owner');
    andThen(() => {
      assert.ok(this.owned);
      assert.equal(this.$('.post-admin-menu').length, 0, 'also hides the menu');
    });
  }
});

widgetTest("reply", {
  template: '{{mount-widget widget="post" args=args replyToPost="replyToPost"}}',
  setup() {
    this.set('args', { canCreatePost: true });
    this.on('replyToPost', () => this.replied = true);
  },
  test(assert) {
    click('.post-controls .create');
    andThen(() => {
      assert.ok(this.replied);
    });
  }
});

widgetTest("reply - without permissions", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', { canCreatePost: false });
  },
  test(assert) {
    assert.equal(this.$('.post-controls .create').length, 0);
  }
});

widgetTest("replies - no replies", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', {replyCount: 0});
  },
  test(assert) {
    assert.equal(this.$('button.show-replies').length, 0);
  }
});

widgetTest("replies - multiple replies", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.siteSettings.suppress_reply_directly_below = true;
    this.set('args', {replyCount: 2, replyDirectlyBelow: true});
  },
  test(assert) {
    assert.equal(this.$('button.show-replies').length, 1);
  }
});

widgetTest("replies - one below, suppressed", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.siteSettings.suppress_reply_directly_below = true;
    this.set('args', {replyCount: 1, replyDirectlyBelow: true});
  },
  test(assert) {
    assert.equal(this.$('button.show-replies').length, 0);
  }
});

widgetTest("replies - one below, not suppressed", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.siteSettings.suppress_reply_directly_below = false;
    this.set('args', {id: 6654, replyCount: 1, replyDirectlyBelow: true});
  },
  test(assert) {
    click('button.show-replies');
    andThen(() => {
      assert.equal(this.$('section.embedded-posts.bottom .cooked').length, 1);
      assert.equal(this.$('section.embedded-posts i.fa-arrow-down').length, 1);
    });
  }
});

widgetTest("topic map not shown", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', { showTopicMap: false });
  },
  test(assert) {
    assert.equal(this.$('.topic-map').length, 0);
  }
});

widgetTest("topic map - few posts", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', {
      showTopicMap: true,
      topicPostsCount: 2,
      participants: [
        {username: 'eviltrout'},
        {username: 'codinghorror'},
      ]
    });
  },
  test(assert) {
    assert.equal(this.$('li.avatars a.poster').length, 0, 'shows no participants when collapsed');

    click('nav.buttons button');
    andThen(() => {
      assert.equal(this.$('.topic-map-expanded a.poster').length, 2, 'shows all when expanded');
    });
  }
});

widgetTest("topic map - participants", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', {
      showTopicMap: true,
      topicPostsCount: 10,
      participants: [
        {username: 'eviltrout'},
        {username: 'codinghorror'},
        {username: 'sam'},
        {username: 'ZogStrIP'},
      ],
      userFilters: ['sam', 'codinghorror']
    });
  },
  test(assert) {
    assert.equal(this.$('li.avatars a.poster').length, 3, 'limits to three participants');

    click('nav.buttons button');
    andThen(() => {
      assert.equal(this.$('li.avatars a.poster').length, 0);
      assert.equal(this.$('.topic-map-expanded a.poster').length, 4, 'shows all when expanded');
      assert.equal(this.$('a.poster.toggled').length, 2, 'two are toggled');
    });
  }
});

widgetTest("topic map - links", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', {
      showTopicMap: true,
      topicLinks: [
        {url: 'http://link1.example.com', clicks: 0},
        {url: 'http://link2.example.com', clicks: 0},
        {url: 'http://link3.example.com', clicks: 0},
        {url: 'http://link4.example.com', clicks: 0},
        {url: 'http://link5.example.com', clicks: 0},
        {url: 'http://link6.example.com', clicks: 0},
      ]
    });
  },
  test(assert) {
    assert.equal(this.$('.topic-map').length, 1);
    assert.equal(this.$('.map.map-collapsed').length, 1);
    assert.equal(this.$('.topic-map-expanded').length, 0);

    click('nav.buttons button');
    andThen(() => {
      assert.equal(this.$('.map.map-collapsed').length, 0);
      assert.equal(this.$('.topic-map i.fa-chevron-up').length, 1);
      assert.equal(this.$('.topic-map-expanded').length, 1);
      assert.equal(this.$('.topic-map-expanded .topic-link').length, 5, 'it limits the links displayed');
    });

    click('.link-summary a');
    andThen(() => {
      assert.equal(this.$('.topic-map-expanded .topic-link').length, 6, 'all links now shown');
    });
  }
});

widgetTest("topic map - no summary", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', { showTopicMap: true });
  },
  test(assert) {
    assert.equal(this.$('.toggle-summary').length, 0);
  }
});

widgetTest("topic map - has summary", {
  template: '{{mount-widget widget="post" args=args toggleSummary="toggleSummary"}}',
  setup() {
    this.set('args', { showTopicMap: true, hasTopicSummary: true });
    this.on('toggleSummary', () => this.summaryToggled = true);
  },
  test(assert) {
    assert.equal(this.$('.toggle-summary').length, 1);

    click('.toggle-summary button');
    andThen(() => assert.ok(this.summaryToggled));
  }
});

widgetTest("pm map", {
  template: '{{mount-widget widget="post" args=args}}',
  setup() {
    this.set('args', {
      showTopicMap: true,
      showPMMap: true,
      allowedGroups: [],
      allowedUsers: [ Ember.Object.create({ username: 'eviltrout' }) ]
    });
  },
  test(assert) {
    assert.equal(this.$('.private-message-map').length, 1);
    assert.equal(this.$('.private-message-map .user').length, 1);
  }
});
