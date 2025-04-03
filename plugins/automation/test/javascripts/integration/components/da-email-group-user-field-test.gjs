import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DaEmailGroupUserField from "discourse/plugins/automation/admin/components/fields/da-email-group-user-field";

module("Integration | Component | email-group-user-field", function (hooks) {
  setupRenderingTest(hooks);

  test("Email group user field uses email-group-user-chooser component", async function (assert) {
    const template = <template>
      <DaEmailGroupUserField @label="a label" />
    </template>;

    await render(template);

    assert.dom(".control-label").hasText("a label");
    assert
      .dom(
        ".controls details.select-kit.multi-select.user-chooser.email-group-user-chooser"
      )
      .exists("has email-group-user-chooser");
  });
});
