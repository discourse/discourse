import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | email-group-user-field", function (hooks) {
  setupRenderingTest(hooks);

  test("Email group user field uses email-group-user-chooser component", async function (assert) {
    const template = hbs` <Fields::DaEmailGroupUserField @label="a label" />`;

    await render(template);

    assert.dom(".control-label").hasText("a label");
    assert.ok(
      exists(
        ".controls details.select-kit.multi-select.user-chooser.email-group-user-chooser"
      ),
      "has email-group-user-chooser"
    );
  });
});
