import { hash } from "@ember/helper";
import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ComboBox from "select-kit/components/combo-box";

module(
  "Integration | Component | consistent input/dropdown/button sizes",
  function (hooks) {
    setupRenderingTest(hooks);

    test("icon only button, icon and text button, text only button", async function (assert) {
      await render(
        <template>
          <DButton @icon="plus" />
          <DButton @icon="plus" @label="topic.create" />
          <DButton @label="topic.create" />
        </template>
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
        <template>
          <TextField /> <DButton @icon="plus" @label="topic.create" />
        </template>
      );

      assert.strictEqual(
        find("input").offsetHeight,
        find(".btn").offsetHeight,
        "have equal height"
      );
    });

    test("combo box + input", async function (assert) {
      await render(
        <template>
          <ComboBox @options={{hash none="category.none"}} /> <TextField />
        </template>
      );

      assert.strictEqual(
        find("input").offsetHeight,
        find(".combo-box").offsetHeight,
        "have equal height"
      );
    });
  }
);
