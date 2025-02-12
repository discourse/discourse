import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostMenu from "discourse/components/post/menu";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Unit | Component | post-menu", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.glimmer_post_menu_mode = "enabled";
    this.siteSettings.post_menu_hidden_items = "";

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
    this.set("args", {});
  });

  test("post-menu-toggle-like-action behavior transformer", async function (assert) {
    let behaviorChanged = false;

    withPluginApi("2.0.0", (api) => {
      api.registerBehaviorTransformer("post-menu-toggle-like-action", () => {
        behaviorChanged = true;
      });
    });

    const post = this.post; // using this inside the template does not correspond to the test `this` context
    await render(<template><PostMenu @post={{post}} /></template>);

    await click(".post-action-menu__like");
    assert.true(behaviorChanged, "behavior transformer was called");
  });
});
