import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { count } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | Widget | actions-summary", function (hooks) {
  setupRenderingTest(hooks);

  test("post deleted", async function (assert) {
    this.set("args", {
      deleted_at: "2016-01-01",
      deletedByUsername: "eviltrout",
      deletedByAvatarTemplate: "/images/avatar.png",
    });

    await render(
      hbs`<MountWidget @widget="actions-summary" @args={{this.args}} />`
    );

    assert.strictEqual(
      count(".post-action .d-icon-far-trash-alt"),
      1,
      "it has the deleted icon"
    );
    assert.strictEqual(
      count(".avatar[title=eviltrout]"),
      1,
      "it has the deleted by avatar"
    );
  });
});
