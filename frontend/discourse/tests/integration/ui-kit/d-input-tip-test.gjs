import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DInputTip from "discourse/ui-kit/d-input-tip";

module("Integration | ui-kit | DInputTip", function (hooks) {
  setupRenderingTest(hooks);

  test("a failed validation shows its reason with a cross", async function (assert) {
    const validation = { failed: true, reason: "Too short" };

    await render(<template><DInputTip @validation={{validation}} /></template>);

    assert.dom(".tip").hasClass("bad", "the tip is marked bad");
    assert.dom(".tip .d-icon-xmark").exists("a cross is shown");
    assert.dom(".tip").hasText("Too short", "the reason is shown");
  });

  test("a passed validation shows its reason with a check", async function (assert) {
    const validation = { ok: true, reason: "Looks good" };

    await render(<template><DInputTip @validation={{validation}} /></template>);

    assert.dom(".tip").hasClass("good", "the tip is marked good");
    assert.dom(".tip .d-icon-check").exists("a check is shown");
    assert.dom(".tip").hasText("Looks good", "the reason is shown");
  });

  test("a validation without a reason renders an empty tip", async function (assert) {
    const validation = { failed: true };

    await render(<template><DInputTip @validation={{validation}} /></template>);

    assert.dom(".tip").hasClass("bad", "the tip is still marked bad");
    assert.dom(".tip .d-icon").doesNotExist("no icon is shown");
    assert.dom(".tip").hasNoText("no text is shown");
  });

  test("@id and attributes reach the tip", async function (assert) {
    await render(
      <template>
        <DInputTip
          class="extra"
          @id="username-validation"
          @validation={{null}}
        />
      </template>
    );

    assert
      .dom("#username-validation")
      .hasClass("tip", "@id is the tip's id")
      .hasClass("extra", "attributes reach the tip");
  });
});
