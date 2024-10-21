import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Widget | small-user-list", function (hooks) {
  setupRenderingTest(hooks);

  test("renders avatars and support for unknown", async function (assert) {
    this.set("args", {
      users: [
        { id: 456, username: "eviltrout" },
        { id: 457, username: "someone", unknown: true },
      ],
    });

    await render(
      hbs`<MountWidget @widget="small-user-list" @args={{this.args}} />`
    );

    assert.dom('[data-user-card="eviltrout"]').exists({ count: 1 });
    assert.dom('[data-user-card="someone"]').doesNotExist();
    assert.dom(".unknown").exists("includes unknown user");
  });
});
