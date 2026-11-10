import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ComposerActionTitle from "discourse/components/composer-action-title";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | ComposerActionTitle", function (hooks) {
  setupRenderingTest(hooks);

  test("offers to change the reply target only for a post edit", async function (assert) {
    const store = this.owner.lookup("service:store");
    const topic = store.createRecord("topic", { id: 1, title: "A topic" });
    const post = store.createRecord("post", {
      id: 2,
      post_number: 2,
      can_edit: true,
      topic,
    });
    const model = store.createRecord("composer", {
      action: "edit",
      topic,
      post,
      reply_to_user: {
        username: "eviltrout",
        avatar_template: "/images/avatar.png",
      },
    });

    await render(<template><ComposerActionTitle @model={{model}} /></template>);

    assert
      .dom(".composer-edit-reply-to")
      .exists("offers the change while editing a post");

    model.set("action", "editSharedDraft");
    await settled();

    assert
      .dom(".original-username")
      .hasText("eviltrout", "still shows the reply target");
    assert
      .dom(".composer-edit-reply-to")
      .doesNotExist("does not offer the change for a shared draft edit");
  });
});
