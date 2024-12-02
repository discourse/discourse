import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Widget | post-links", function (hooks) {
  setupRenderingTest(hooks);

  test("duplicate links", async function (assert) {
    this.set("args", {
      id: 2,
      links: [
        {
          title: "Evil Trout Link",
          url: "http://eviltrout.com",
          reflection: true,
        },
        {
          title: "Evil Trout Link",
          url: "http://dupe.eviltrout.com",
          reflection: true,
        },
      ],
    });

    await render(hbs`<MountWidget @widget="post-links" @args={{this.args}} />`);

    assert
      .dom(".post-links a.track-link")
      .exists({ count: 1 }, "hides the dupe link");
  });

  test("collapsed links", async function (assert) {
    this.set("args", {
      id: 1,
      links: [
        {
          title: "Link 1",
          url: "http://eviltrout.com?1",
          reflection: true,
        },
        {
          title: "Link 2",
          url: "http://eviltrout.com?2",
          reflection: true,
        },
        {
          title: "Link 3",
          url: "http://eviltrout.com?3",
          reflection: true,
        },
        {
          title: "Link 4",
          url: "http://eviltrout.com?4",
          reflection: true,
        },
        {
          title: "Link 5",
          url: "http://eviltrout.com?5",
          reflection: true,
        },
        {
          title: "Link 6",
          url: "http://eviltrout.com?6",
          reflection: true,
        },
        {
          title: "Link 7",
          url: "http://eviltrout.com?7",
          reflection: true,
        },
      ],
    });

    await render(hbs`<MountWidget @widget="post-links" @args={{this.args}} />`);

    assert.dom(".expand-links").exists({ count: 1 }, "collapsed by default");

    await click("a.expand-links");
    assert.dom(".post-links a.track-link").exists({ count: 7 });
  });
});
