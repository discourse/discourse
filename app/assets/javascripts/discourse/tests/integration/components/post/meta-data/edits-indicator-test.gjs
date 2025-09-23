import { getOwner } from "@ember/owner";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostMetaDataEditsIndicator from "discourse/components/post/meta-data/edits-indicator";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function renderComponent(post) {
  return render(
    <template><PostMetaDataEditsIndicator @post={{post}} /></template>
  );
}

module(
  "Integration | Component | Post | PostMetaDataEditsIndicator",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.store = getOwner(this).lookup("service:store");
      const topic = this.store.createRecord("topic", { id: 1 });
      const post = this.store.createRecord("post", {
        id: 123,
        post_number: 1,
        topic,
        like_count: 3,
        actions_summary: [{ id: 2, count: 1, hidden: false, can_act: true }],
      });

      this.post = post;
    });

    test("basic rendering", async function (assert) {
      this.post.username = "eviltrout";
      this.post.name = "Robin Ward";
      this.post.user_title = "Trout Master";

      await renderComponent(this.post);

      assert.dom(".post-info.edits button").exists().hasText(/\s+/);

      this.post.version = 2;
      await settled();

      assert.dom(".post-info.edits button").exists().hasText("1");
    });

    test("customize labels using the post-meta-data-edits-indicator-label transformer", async function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "post-meta-data-edits-indicator-label",
          ({ value }) => {
            if (value) {
              return "(edited)";
            } else {
              return "(original)";
            }
          }
        );
      });

      await renderComponent(this.post);
      assert.dom(".post-info.edits button").hasText("(original)");

      this.post.version = 2;
      await settled();

      assert.dom(".post-info.edits button").hasText("(edited)");
    });
  }
);
