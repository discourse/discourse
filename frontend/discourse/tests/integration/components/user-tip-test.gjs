import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import UserTip from "discourse/components/user-tip";
import DTooltips from "discourse/float-kit/components/d-tooltips";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | UserTip", function (hooks) {
  setupRenderingTest(hooks);

  test("shows the last user tip when there are no priorities", async function (assert) {
    const site = getOwner(this).lookup("service:site");
    site.user_tips = { foo: 1, bar: 2, baz: 3 };

    await render(
      <template>
        <UserTip @id="foo" @titleText="first tip" />
        <UserTip @id="bar" @titleText="second tip" />
        <UserTip @id="baz" @titleText="third tip" />
        <DTooltips />
      </template>
    );

    assert.dom(".user-tip__title").hasText("third tip");
  });
});
