import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";

import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | consistent input/dropdown/button sizes",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("icon only button, icon and text button, text only button", {
      template: hbs`{{d-button icon="plus"}} {{d-button icon="plus" label="topic.create"}} {{d-button label="topic.create"}}`,

      test(assert) {
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
      },
      // these tests fail on Firefox 78 in CI, skipping for now
      skip: !navigator.userAgent.includes("Chrome"),
    });

    componentTest("button + text input", {
      template: hbs`{{text-field}} {{d-button icon="plus" label="topic.create"}}`,

      test(assert) {
        assert.strictEqual(
          query("input").offsetHeight,
          query(".btn").offsetHeight,
          "have equal height"
        );
      },

      skip: !navigator.userAgent.includes("Chrome"),
    });

    componentTest("combo box + input", {
      template: hbs`{{combo-box options=(hash none="category.none")}} {{text-field}}`,

      test(assert) {
        assert.strictEqual(
          query("input").offsetHeight,
          query(".combo-box").offsetHeight,
          "have equal height"
        );
      },

      skip: !navigator.userAgent.includes("Chrome"),
    });
  }
);
