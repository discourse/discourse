import { moduleForWidget, widgetTest } from 'helpers/widget-test';

moduleForWidget('post-links');

widgetTest("duplicate links", {
  template: '{{mount-widget widget="post-links" args=args}}',
  setup() {
    this.set('args', {
      id: 2,
      links: [
        { title: "Evil Trout Link", url: "http://eviltrout.com" },
        { title: "Evil Trout Link", url: "http://dupe.eviltrout.com" }
      ]
    });
  },
  test(assert) {
    click('.expand-links');
    andThen(() => {
      assert.equal(this.$('.post-links a.track-link').length, 1, 'it hides the dupe link');
    });
  }
});

widgetTest("collapsed links", {
  template: '{{mount-widget widget="post-links" args=args}}',
  setup() {
    this.set('args', {
      id: 1,
      links: [
        { title: "Link 1", url: "http://eviltrout.com?1" },
        { title: "Link 2", url: "http://eviltrout.com?2" },
        { title: "Link 3", url: "http://eviltrout.com?3" },
        { title: "Link 4", url: "http://eviltrout.com?4" },
        { title: "Link 5", url: "http://eviltrout.com?5" },
        { title: "Link 6", url: "http://eviltrout.com?6" },
        { title: "Link 7", url: "http://eviltrout.com?7" },
      ]
    });
  },
  test(assert) {
    assert.ok(this.$('.expand-links').length, 'collapsed by default');
    click('a.expand-links');
    andThen(() => {
      assert.equal(this.$('.post-links a.track-link').length, 7);
    });
  }
});

// widgetTest("reply as new topic", {
//   template: '{{mount-widget widget="post-links" args=args newTopicAction="newTopicAction"}}',
//   setup() {
//     this.set('args', { canReplyAsNewTopic: true });
//     this.on('newTopicAction', () => this.newTopicTriggered = true);
//   },
//   test(assert) {
//     click('a.reply-new');
//     andThen(() => assert.ok(this.newTopicTriggered));
//   }
// });
