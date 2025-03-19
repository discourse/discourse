import { find, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | consistent input/dropdown/button sizes",
  function (hooks) {
    setupRenderingTest(hooks);

    test("icon only button, icon and text button, text only button", async function (assert) {
      await render(
        hbs`<DButton @icon="plus" /> <DButton @icon="plus" @label="topic.create" /> <DButton @label="topic.create" />`
      );

      assert.strictEqual(
        find(".btn:nth-child(1)").offsetHeight,
        find(".btn:nth-child(2)").offsetHeight,
        "have equal height"
      );
      assert.strictEqual(
        find(".btn:nth-child(1)").offsetHeight,
        find(".btn:nth-child(3)").offsetHeight,
        "have equal height"
      );
    });

    test("button + text input", async function (assert) {
      await render(
        hbs`<TextField /> <DButton @icon="plus" @label="topic.create" />`
      );

      assert.strictEqual(
        find("input").offsetHeight,
        find(".btn").offsetHeight,
        "have equal height"
      );
    });

    test("combo box + input", async function (assert) {
      await render(
        hbs`<ComboBox @options={{hash none="category.none"}} /> <TextField />`
      );

      assert.strictEqual(
        find("input").offsetHeight,
        find(".combo-box").offsetHeight,
        "have equal height"
      );
    });
  }
);
