import Service from "@ember/service";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import EmailStylesEditor from "discourse/admin/components/email-styles-editor";
import EmailStyle from "discourse/admin/models/email-style";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

class DialogStub extends Service {
  yesNoConfirm(options) {
    options.didConfirm();
  }
}

module("Integration | Component | EmailStylesEditor", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.register("service:dialog", DialogStub);
  });

  test("resetting follows the edited field", async function (assert) {
    const styles = EmailStyle.create({
      css: "body { color: red; }",
      default_css: "body { color: red; }",
    });

    await render(
      <template>
        <EmailStylesEditor @fieldName="css" @styles={{styles}} />
      </template>
    );

    assert
      .dom(".btn-default")
      .isDisabled("there is nothing to reset while css matches its default");

    styles.setField("css", "body { color: blue; }");
    await settled();

    assert.dom(".btn-default").isEnabled("an edited field can be reset");

    await click(".btn-default");

    assert.strictEqual(
      styles.css,
      "body { color: red; }",
      "resetting restores the default"
    );
    assert
      .dom(".btn-default")
      .isDisabled("the reset field matches its default again");
  });
});
