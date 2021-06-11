import { click, fillIn } from "@ember/test-helpers";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  count,
  discourseModule,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | secret-value-list",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("adding a value", {
      template: hbs`{{secret-value-list values=values}}`,

      async test(assert) {
        this.set("values", "firstKey|FirstValue\nsecondKey|secondValue");

        await fillIn(".new-value-input.key", "thirdKey");
        await click(".add-value-btn");

        assert.equal(
          count(".values .value"),
          2,
          "it doesn't add the value to the list if secret is missing"
        );

        await fillIn(".new-value-input.key", "");
        await fillIn(".new-value-input.secret", "thirdValue");
        await click(".add-value-btn");

        assert.equal(
          count(".values .value"),
          2,
          "it doesn't add the value to the list if key is missing"
        );

        await fillIn(".new-value-input.key", "thirdKey");
        await fillIn(".new-value-input.secret", "thirdValue");
        await click(".add-value-btn");

        assert.equal(
          count(".values .value"),
          3,
          "it adds the value to the list of values"
        );

        assert.deepEqual(
          this.values,
          "firstKey|FirstValue\nsecondKey|secondValue\nthirdKey|thirdValue",
          "it adds the value to the list of values"
        );
      },
    });

    componentTest("adding an invalid value", {
      template: hbs`{{secret-value-list values=values}}`,

      async test(assert) {
        await fillIn(".new-value-input.key", "someString");
        await fillIn(".new-value-input.secret", "keyWithAPipe|Hidden");
        await click(".add-value-btn");

        assert.ok(
          !exists(".values .value"),
          "it doesn't add the value to the list of values"
        );

        assert.deepEqual(
          this.values,
          undefined,
          "it doesn't add the value to the list of values"
        );

        assert.ok(
          queryAll(".validation-error")
            .html()
            .indexOf(I18n.t("admin.site_settings.secret_list.invalid_input")) >
            -1,
          "it shows validation error"
        );
      },
    });

    componentTest("removing a value", {
      template: hbs`{{secret-value-list values=values}}`,

      async test(assert) {
        this.set("values", "firstKey|FirstValue\nsecondKey|secondValue");

        await click(".values .value[data-index='0'] .remove-value-btn");

        assert.equal(
          count(".values .value"),
          1,
          "it removes the value from the list of values"
        );

        assert.equal(
          this.values,
          "secondKey|secondValue",
          "it removes the expected value"
        );
      },
    });
  }
);
