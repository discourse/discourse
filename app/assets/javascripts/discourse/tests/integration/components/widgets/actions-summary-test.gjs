import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MountWidget from "discourse/components/mount-widget";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// TODO (glimmer-post-stream) remove this test when removing the widget post stream code
module("Integration | Component | Widget | actions-summary", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 123 });
    const post = store.createRecord("post", {
      id: 1,
      post_number: 2,
      topic,
      deleted_at: "2016-01-01",
      deleted_by: {
        username: "eviltrout",
        avatar_template: "/images/avatar.png",
      },
    });

    this.set("post", post);
  });

  test("post deleted", async function (assert) {
    const data = { post: this.post };
    await render(
      <template>
        <MountWidget @widget="actions-summary" @args={{data}} />
      </template>
    );

    assert.dom(".post-action .d-icon-trash-can").exists("has the deleted icon");
    assert.dom(".avatar[title=eviltrout]").exists("has the deleted by avatar");
  });
});
