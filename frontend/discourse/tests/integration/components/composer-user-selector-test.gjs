import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ComposerUserSelector from "discourse/components/composer-user-selector";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | ComposerUserSelector", function (hooks) {
  setupRenderingTest(hooks);

  test("focuses the recipients chooser when it is the focus target", async function (assert) {
    await render(
      <template><ComposerUserSelector @focusTarget="usernames" /></template>
    );

    assert.dom("#private-message-users .select-kit-header").isFocused();
  });

  test("leaves focus alone for another focus target", async function (assert) {
    await render(
      <template><ComposerUserSelector @focusTarget="title" /></template>
    );

    assert.dom("#private-message-users .select-kit-header").isNotFocused();
  });
});
