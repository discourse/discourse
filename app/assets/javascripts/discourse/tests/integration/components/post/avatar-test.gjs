import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostAvatar from "discourse/components/post/avatar";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function renderComponent(post) {
  return render(<template><PostAvatar @post={{post}} /></template>);
}

module("Integration | Component | Post | PostAvatar", function (hooks) {
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

  test("can add classes to the component", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("post-avatar-class", ({ value }) => {
        value.push("custom-class");
        return value;
      });
    });

    await renderComponent(this.post);

    assert
      .dom(".topic-avatar.custom-class")
      .exists("applies the custom classes to the component");
  });
});
