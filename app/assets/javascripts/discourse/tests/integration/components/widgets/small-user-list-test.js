import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { count, exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

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

    assert.strictEqual(count('[data-user-card="eviltrout"]'), 1);
    assert.ok(!exists('[data-user-card="someone"]'));
    assert.ok(exists(".unknown"), "includes unknown user");
  });
});
