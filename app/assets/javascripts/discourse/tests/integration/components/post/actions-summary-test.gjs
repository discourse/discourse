import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostActionsSummary from "discourse/components/post/actions-summary";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function renderComponent(post) {
  return render(<template><PostActionsSummary @post={{post}} /></template>);
}

module("Integration | Component | Post | PostActionsSummary", function (hooks) {
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

  test("post deleted (first post)", async function (assert) {
    this.post.topic.deleted_at = "2016-01-01";
    this.post.topic.deleted_by = {
      username: "eviltrout",
      avatar_template: "/images/avatar.png",
    };

    await renderComponent(this.post);

    assert.dom(".post-action .d-icon-trash-can").exists("has the deleted icon");
    assert.dom(".avatar[title=eviltrout]").exists("has the deleted by avatar");
  });

  test("post deleted (other posts)", async function (assert) {
    this.post.post_number = 2;
    this.post.deleted_at = "2016-01-01";
    this.post.deleted_by = {
      username: "eviltrout",
      avatar_template: "/images/avatar.png",
    };

    await renderComponent(this.post);

    assert.dom(".post-action .d-icon-trash-can").exists("has the deleted icon");
    assert.dom(".avatar[title=eviltrout]").exists("has the deleted by avatar");
  });
});
