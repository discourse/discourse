import { blur, click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import SecretValueList from "admin/components/secret-value-list";

module("Integration | Component | secret-value-list", function (hooks) {
  setupRenderingTest(hooks);

  test("adding a value", async function (assert) {
    const self = this;

    this.set("setValidationMessage", () => {});

    await render(
      <template>
        <SecretValueList
          @values={{self.values}}
          @setValidationMessage={{self.setValidationMessage}}
        />
      </template>
    );

    this.set("values", "firstKey|FirstValue\nsecondKey|secondValue");

    await fillIn(".new-value-input.key", "thirdKey");
    await click(".add-value-btn");

    assert
      .dom(".values .value")
      .exists(
        { count: 2 },
        "doesn't add the value to the list if secret is missing"
      );

    await fillIn(".new-value-input.key", "");
    await fillIn(".new-value-input.secret", "thirdValue");
    await click(".add-value-btn");

    assert
      .dom(".values .value")
      .exists(
        { count: 2 },
        "doesn't add the value to the list if key is missing"
      );

    await fillIn(".new-value-input.key", "thirdKey");
    await fillIn(".new-value-input.secret", "thirdValue");
    await click(".add-value-btn");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");

    assert.deepEqual(
      this.values,
      "firstKey|FirstValue\nsecondKey|secondValue\nthirdKey|thirdValue",
      "it adds the value to the list of values"
    );
  });

  test("adding an invalid value", async function (assert) {
    const self = this;

    let setValidationMessage = (message) => {
      this.set("message", message);
    };
    this.set("setValidationMessage", setValidationMessage);

    await render(
      <template>
        <SecretValueList
          @values={{self.values}}
          @setValidationMessage={{self.setValidationMessage}}
        />
      </template>
    );

    await fillIn(".new-value-input.key", "someString");
    await fillIn(".new-value-input.secret", "keyWithAPipe|Hidden");
    await click(".add-value-btn");

    assert
      .dom(".values .value")
      .doesNotExist("it doesn't add the value to the list of values");

    assert.deepEqual(
      this.values,
      undefined,
      "it doesn't add the value to the list of values"
    );

    assert.strictEqual(
      this.message,
      i18n("admin.site_settings.secret_list.invalid_input"),
      "it shows validation error"
    );
  });

  test("changing a value", async function (assert) {
    const self = this;

    this.set("setValidationMessage", () => {});

    await render(
      <template>
        <SecretValueList
          @values={{self.values}}
          @setValidationMessage={{self.setValidationMessage}}
        />
      </template>
    );

    this.set("values", "firstKey|FirstValue\nsecondKey|secondValue");

    await fillIn(
      ".values .value[data-index='1'] .value-input:first-of-type",
      "changedKey"
    );
    await blur(".values .value[data-index='1'] .value-input:first-of-type");

    assert
      .dom(".values .value[data-index='1'] .value-input:first-of-type")
      .hasValue("changedKey");

    await fillIn(
      ".values .value[data-index='1'] .value-input:last-of-type",
      "changedValue"
    );
    await blur(".values .value[data-index='1'] .value-input:last-of-type");

    assert
      .dom(".values .value[data-index='1'] .value-input:last-of-type")
      .hasValue("changedValue");
    assert.deepEqual(
      this.values,
      "firstKey|FirstValue\nchangedKey|changedValue",
      "updates the value list"
    );
  });

  test("removing a value", async function (assert) {
    const self = this;

    this.set("setValidationMessage", () => {});

    await render(
      <template>
        <SecretValueList
          @values={{self.values}}
          @setValidationMessage={{self.setValidationMessage}}
        />
      </template>
    );

    this.set("values", "firstKey|FirstValue\nsecondKey|secondValue");

    await click(".values .value[data-index='0'] .remove-value-btn");

    assert
      .dom(".values .value")
      .exists({ count: 1 }, "removes the value from the list of values");

    assert.strictEqual(
      this.values,
      "secondKey|secondValue",
      "it removes the expected value"
    );
  });
});
