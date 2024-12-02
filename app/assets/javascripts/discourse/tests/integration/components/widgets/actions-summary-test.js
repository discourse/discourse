import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

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

    assert.dom(".post-action .d-icon-trash-can").exists("has the deleted icon");
    assert.dom(".avatar[title=eviltrout]").exists("has the deleted by avatar");
  });
});
