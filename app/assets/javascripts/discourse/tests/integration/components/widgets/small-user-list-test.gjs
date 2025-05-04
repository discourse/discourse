import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MountWidget from "discourse/components/mount-widget";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// TODO (glimmer-post-stream) remove this test when removing the widget post stream code
module("Integration | Component | Widget | small-user-list", function (hooks) {
  setupRenderingTest(hooks);

  test("renders avatars and support for unknown", async function (assert) {
    const args = {
      users: [
        { id: 456, username: "eviltrout" },
        { id: 457, username: "someone", unknown: true },
      ],
      isVisible: true,
    };

    await render(
      <template>
        <MountWidget @widget="small-user-list" @args={{args}} />
      </template>
    );

    assert.dom('[data-user-card="eviltrout"]').exists({ count: 1 });
    assert.dom('[data-user-card="someone"]').doesNotExist();
    assert.dom(".unknown").exists("includes unknown user");
  });
});
