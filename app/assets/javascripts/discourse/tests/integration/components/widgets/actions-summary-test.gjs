import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MountWidget from "discourse/components/mount-widget";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// TODO (glimmer-post-stream) remove this test when removing the widget post stream code
module("Integration | Component | Widget | actions-summary", function (hooks) {
  setupRenderingTest(hooks);

  test("post deleted", async function (assert) {
    const args = {
      deletedAt: "2016-01-01",
      deletedBy: {
        username: "eviltrout",
        avatar_template: "/images/avatar.png",
      },
    };

    await render(
      <template>
        <MountWidget @widget="actions-summary" @args={{args}} />
      </template>
    );

    assert.dom(".post-action .d-icon-trash-can").exists("has the deleted icon");
    assert.dom(".avatar[title=eviltrout]").exists("has the deleted by avatar");
  });
});
