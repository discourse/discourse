import { moduleForWidget, widgetTest } from "helpers/widget-test";

moduleForWidget("post-links");

widgetTest("duplicate links", {
  template: '{{mount-widget widget="post-links" args=args}}',
  beforeEach() {
    this.set("args", {
      id: 2,
      links: [
        {
          title: "Evil Trout Link",
          url: "http://eviltrout.com",
          reflection: true
        },
        {
          title: "Evil Trout Link",
          url: "http://dupe.eviltrout.com",
          reflection: true
        }
      ]
    });
  },
  test(assert) {
    assert.equal(
      this.$(".post-links a.track-link").length,
      1,
      "it hides the dupe link"
    );
  }
});

widgetTest("collapsed links", {
  template: '{{mount-widget widget="post-links" args=args}}',
  beforeEach() {
    this.set("args", {
      id: 1,
      links: [
        { title: "Link 1", url: "http://eviltrout.com?1", reflection: true },
        { title: "Link 2", url: "http://eviltrout.com?2", reflection: true },
        { title: "Link 3", url: "http://eviltrout.com?3", reflection: true },
        { title: "Link 4", url: "http://eviltrout.com?4", reflection: true },
        { title: "Link 5", url: "http://eviltrout.com?5", reflection: true },
        { title: "Link 6", url: "http://eviltrout.com?6", reflection: true },
        { title: "Link 7", url: "http://eviltrout.com?7", reflection: true }
      ]
    });
  },
  test(assert) {
    assert.ok(this.$(".expand-links").length === 1, "collapsed by default");
    click("a.expand-links");
    andThen(() => {
      assert.equal(this.$(".post-links a.track-link").length, 7);
    });
  }
});
