import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostLinks from "discourse/components/post/links";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function renderComponent(post) {
  return render(<template><PostLinks @post={{post}} /></template>);
}

module("Integration | Component | Post | PostLinks", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.glimmer_post_stream_mode = "enabled";

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 1 });
    const post = store.createRecord("post", {
      id: 123,
      post_number: 1,
      topic,
      like_count: 3,
      actions_summary: [{ id: 2, count: 1, hidden: false, can_act: true }],
    });

    this.post = post;
  });

  test("duplicate links", async function (assert) {
    this.post.link_counts = [
      {
        title: "Link 1",
        url: "/t/1",
        internal: true,
        reflection: true,
        clicks: 2,
      },
      {
        title: "Link 1",
        url: "/t/1?dupe",
        internal: true,
        reflection: true,
      },
      {
        url: "/groups/test",
        internal: true,
        reflection: false,
      },
      {
        title: "Evil Trout Link",
        url: "http://eviltrout.com",
        internal: false,
        reflection: false,
      },
      {
        title: "Evil Trout Link",
        url: "http://dupe.eviltrout.com",
        internal: false,
        reflection: false,
      },
    ];

    await renderComponent(this.post);

    assert.dom(".expand-links").doesNotExist("there is no expand button");

    assert
      .dom(".post-links a.track-link")
      .exists({ count: 1 }, "hides the dupe link")
      .hasAttribute("data-clicks", "2", "has the correct click count");
  });

  test("collapsed links", async function (assert) {
    this.post.link_counts = [
      {
        title: "Link 1",
        url: "/t/1",
        internal: true,
        reflection: true,
      },
      {
        title: "Link 2",
        url: "/t/2",
        internal: true,
        reflection: true,
      },
      {
        title: "Link 3",
        url: "/t/3",
        internal: true,
        reflection: true,
      },
      {
        title: "Link 4",
        url: "/t/4",
        internal: true,
        reflection: true,
      },
      {
        title: "Link 5",
        url: "/t/5",
        internal: true,
        reflection: true,
      },
      {
        title: "Link 6",
        url: "/t/6",
        internal: true,
        reflection: true,
      },
      {
        title: "Link 7",
        url: "/t/7",
        internal: true,
        reflection: true,
      },
    ];

    await renderComponent(this.post);

    assert.dom(".expand-links").exists({ count: 1 }, "collapsed by default");

    await click(".expand-links");

    assert.dom(".post-links a.track-link").exists({ count: 7 });
    assert.dom(".expand-links").doesNotExist("there is no expand button");
  });

  test("data-clicks", async function (assert) {
    this.post.link_counts = [
      {
        title: "Link 1",
        url: "/t/1",
        internal: true,
        reflection: true,
        clicks: 2,
      },
      {
        title: "Link 2",
        url: "/t/2",
        internal: true,
        reflection: true,
        clicks: 0,
      },
    ];

    await renderComponent(this.post);

    assert
      .dom(".post-links a.track-link[href='/t/1']")
      .hasAttribute("data-clicks", "2", "Link 1 has the correct click count");

    assert
      .dom(".post-links a.track-link[href='/t/2']")
      .doesNotHaveAttribute("data-clicks");
  });
});
