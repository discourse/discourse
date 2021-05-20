import { click, fillIn, triggerKeyEvent } from "@ember/test-helpers";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | simple-list", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("adding a value", {
    template: hbs`{{simple-list values=values}}`,

    beforeEach() {
      this.set("values", "vinkas\nosama");
    },

    async test(assert) {
      assert.ok(
        queryAll(".add-value-btn[disabled]").length,
        "while loading the + button is disabled"
      );

      await fillIn(".add-value-input", "penar");
      await click(".add-value-btn");

      assert.ok(
        queryAll(".values .value").length === 3,
        "it adds the value to the list of values"
      );

      assert.ok(
        queryAll(".values .value[data-index='2'] .value-input")[0].value ===
          "penar",
        "it sets the correct value for added item"
      );

      await fillIn(".add-value-input", "eviltrout");
      await triggerKeyEvent(".add-value-input", "keydown", 13); // enter

      assert.ok(
        queryAll(".values .value").length === 4,
        "it adds the value when keying Enter"
      );
    },
  });

  componentTest("removing a value", {
    template: hbs`{{simple-list values=values}}`,

    beforeEach() {
      this.set("values", "vinkas\nosama");
    },

    async test(assert) {
      await click(".values .value[data-index='0'] .remove-value-btn");

      assert.ok(
        queryAll(".values .value").length === 1,
        "it removes the value from the list of values"
      );

      assert.ok(
        queryAll(".values .value[data-index='0'] .value-input")[0].value ===
          "osama",
        "it removes the correct value"
      );
    },
  });

  componentTest("delimiter support", {
    template: hbs`{{simple-list values=values inputDelimiter='|'}}`,

    beforeEach() {
      this.set("values", "vinkas|osama");
    },

    async test(assert) {
      await fillIn(".add-value-input", "eviltrout");
      await click(".add-value-btn");

      assert.ok(
        queryAll(".values .value").length === 3,
        "it adds the value to the list of values"
      );

      assert.ok(
        queryAll(".values .value[data-index='2'] .value-input")[0].value ===
          "eviltrout",
        "it adds the correct value"
      );
    },
  });
});
