import { module } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { chromeTest, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module(
  "Integration | Component | consistent input/dropdown/button sizes",
  function (hooks) {
    setupRenderingTest(hooks);

    // these tests fail on Firefox 78 in CI, skipping for now
    chromeTest(
      "icon only button, icon and text button, text only button",
      async function (assert) {
        await render(
          hbs`<DButton @icon="plus" /> <DButton @icon="plus" @label="topic.create" /> <DButton @label="topic.create" />`
        );

        assert.strictEqual(
          query(".btn:nth-child(1)").offsetHeight,
          query(".btn:nth-child(2)").offsetHeight,
          "have equal height"
        );
        assert.strictEqual(
          query(".btn:nth-child(1)").offsetHeight,
          query(".btn:nth-child(3)").offsetHeight,
          "have equal height"
        );
      }
    );

    chromeTest("button + text input", async function (assert) {
      await render(
        hbs`<TextField /> <DButton @icon="plus" @label="topic.create" />`
      );

      assert.strictEqual(
        query("input").offsetHeight,
        query(".btn").offsetHeight,
        "have equal height"
      );
    });

    chromeTest("combo box + input", async function (assert) {
      await render(
        hbs`<ComboBox @options={{hash none="category.none"}} /> <TextField />`
      );

      assert.strictEqual(
        query("input").offsetHeight,
        query(".combo-box").offsetHeight,
        "have equal height"
      );
    });
  }
);
