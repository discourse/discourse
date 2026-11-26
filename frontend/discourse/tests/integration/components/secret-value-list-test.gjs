import { tracked } from "@glimmer/tracking";
import {
  blur,
  click,
  fillIn,
  focus,
  render,
  settled,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import SecretValueList from "discourse/admin/components/secret-value-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | SecretValueList", function (hooks) {
  setupRenderingTest(hooks);

  test("adding a value", async function (assert) {
    const values = tracked("firstKey|FirstValue\nsecondKey|secondValue");
    const setValidationMessage = () => {};
    const changeValueCallback = (newValues) => (values.value = newValues);

    await render(
      <template>
        <SecretValueList
          @changeValueCallback={{changeValueCallback}}
          @setValidationMessage={{setValidationMessage}}
          @values={{values.value}}
        />
      </template>
    );

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
      values.value,
      "firstKey|FirstValue\nsecondKey|secondValue\nthirdKey|thirdValue",
      "it adds the value to the list of values"
    );
  });

  test("adding an invalid value", async function (assert) {
    const values = tracked(undefined);
    let message;
    const setValidationMessage = (newMessage) => (message = newMessage);
    const changeValueCallback = (newValues) => (values.value = newValues);

    await render(
      <template>
        <SecretValueList
          @changeValueCallback={{changeValueCallback}}
          @setValidationMessage={{setValidationMessage}}
          @values={{values.value}}
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
      values.value,
      undefined,
      "it doesn't add the value to the list of values"
    );

    assert.strictEqual(
      message,
      i18n("admin.site_settings.secret_list.invalid_input"),
      "it shows validation error"
    );
  });

  test("changing a value", async function (assert) {
    const values = tracked("firstKey|FirstValue\nsecondKey|secondValue");
    const setValidationMessage = () => {};
    const changeValueCallback = (newValues) => (values.value = newValues);

    await render(
      <template>
        <SecretValueList
          @changeValueCallback={{changeValueCallback}}
          @setValidationMessage={{setValidationMessage}}
          @values={{values.value}}
        />
      </template>
    );

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
      values.value,
      "firstKey|FirstValue\nchangedKey|changedValue",
      "updates the value list"
    );
  });

  test("removing a value", async function (assert) {
    const values = tracked("firstKey|FirstValue\nsecondKey|secondValue");
    const setValidationMessage = () => {};
    const changeValueCallback = (newValues) => (values.value = newValues);

    await render(
      <template>
        <SecretValueList
          @changeValueCallback={{changeValueCallback}}
          @setValidationMessage={{setValidationMessage}}
          @values={{values.value}}
        />
      </template>
    );

    await click(".values .value[data-index='0'] .remove-value-btn");

    assert
      .dom(".values .value")
      .exists({ count: 1 }, "removes the value from the list of values");

    assert.strictEqual(
      values.value,
      "secondKey|secondValue",
      "it removes the expected value"
    );
  });

  test("revealing secrets one row at a time", async function (assert) {
    const values = tracked("firstKey|FirstValue\nsecondKey|secondValue");
    const setValidationMessage = () => {};
    const changeValueCallback = (newValues) => (values.value = newValues);
    const firstSecret = ".value[data-index='0'] .secret";
    const firstReveal = ".value[data-index='0'] .secret-value-list__reveal";
    const newSecret = ".new-value-input.secret";
    const newReveal = ".secret-value-list > .value .secret-value-list__reveal";

    await render(
      <template>
        <SecretValueList
          @changeValueCallback={{changeValueCallback}}
          @isSecret={{true}}
          @setValidationMessage={{setValidationMessage}}
          @values={{values.value}}
        />
      </template>
    );

    await focus(".value[data-index='0'] .value-input");
    await click(firstReveal);

    assert
      .dom(firstSecret)
      .hasAttribute("type", "text", "reveals on the first click after editing");
    assert.dom(newSecret).hasAttribute("type", "password");

    await click(firstReveal);

    assert.dom(firstSecret).hasAttribute("type", "password", "masks it again");

    await click(newReveal);
    await fillIn(".new-value-input.key", "thirdKey");
    await fillIn(newSecret, "thirdValue");
    await click(".add-value-btn");

    assert
      .dom(newSecret)
      .hasAttribute("type", "password", "masks the next entry after adding");

    await click(firstReveal);
    await click(".values .value[data-index='0'] .remove-value-btn");

    assert
      .dom(firstSecret)
      .hasAttribute(
        "type",
        "password",
        "a removed row's reveal is not inherited"
      );
  });

  test("a reveal follows its entry when the values are restored", async function (assert) {
    const original = "firstKey|FirstValue\nsecondKey|secondValue";
    const values = tracked(original);
    const changeValueCallback = (newValues) => (values.value = newValues);

    await render(
      <template>
        <SecretValueList
          @changeValueCallback={{changeValueCallback}}
          @isSecret={{true}}
          @values={{values.value}}
        />
      </template>
    );

    await click(".values .value[data-index='0'] .remove-value-btn");
    await click(".value[data-index='0'] .secret-value-list__reveal");

    values.value = original;
    await settled();

    assert
      .dom(".value[data-index='0'] .secret")
      .hasAttribute("type", "password", "the restored entry stays masked");
    assert
      .dom(".value[data-index='1'] .secret")
      .hasAttribute("type", "text", "the revealed entry stays revealed");
  });
});
