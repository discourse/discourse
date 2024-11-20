import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Validator from "discourse/form-kit/lib/validator";
import { i18n } from "discourse-i18n";

module("Unit | Lib | FormKit | Validator", function (hooks) {
  setupTest(hooks);

  test("unknown validator", async function (assert) {
    const validator = await new Validator(1, { foo: {} });

    try {
      await validator.validate();
    } catch (e) {
      assert.deepEqual(e.message, "Unknown validator: foo");
    }
  });

  test("length", async function (assert) {
    let errors = await new Validator("", {
      length: { min: 1, max: 5 },
    }).validate();

    assert.deepEqual(
      errors,
      [
        i18n("form_kit.errors.too_short", {
          count: 1,
        }),
      ],
      "it returns an error when the value is too short"
    );

    errors = await new Validator("aaaaaa", {
      length: { min: 1, max: 5 },
    }).validate();
    assert.deepEqual(
      errors,
      [
        i18n("form_kit.errors.too_long", {
          count: 5,
        }),
      ],
      "it returns an error when the value is too long"
    );

    errors = await new Validator("aaa", {
      length: { min: 1, max: 5 },
    }).validate();
    assert.deepEqual(
      errors,
      [],
      "it returns no errors when the value is valid"
    );
  });

  test("between", async function (assert) {
    let errors = await new Validator(0, {
      between: { min: 1, max: 5 },
    }).validate();

    assert.deepEqual(
      errors,
      [
        i18n("form_kit.errors.too_low", {
          count: 1,
        }),
      ],
      "it returns an error when the value is too low"
    );

    errors = await new Validator(6, {
      between: { min: 1, max: 5 },
    }).validate();
    assert.deepEqual(
      errors,
      [
        i18n("form_kit.errors.too_high", {
          count: 5,
        }),
      ],
      "it returns an error when the value is too high"
    );

    errors = await new Validator(5, {
      between: { min: 1, max: 5 },
    }).validate();
    assert.deepEqual(
      errors,
      [],
      "it returns no errors when the value is valid"
    );
  });

  test("integer", async function (assert) {
    let errors = await new Validator(1.2, {
      integer: {},
    }).validate();

    assert.deepEqual(
      errors,
      [i18n("form_kit.errors.not_an_integer")],
      "it returns an error when the value is not an integer"
    );

    errors = await new Validator(1, { integer: {} }).validate();
    assert.deepEqual(
      errors,
      [],
      "it returns no errors when the value is an integer"
    );
  });

  test("number", async function (assert) {
    let errors = await new Validator("A", {
      number: {},
    }).validate();

    assert.deepEqual(
      errors,
      [i18n("form_kit.errors.not_a_number")],
      "it returns an error when the value is not a number"
    );

    errors = await new Validator(1, { number: {} }).validate();
    assert.deepEqual(
      errors,
      [],
      "it returns no errors when the value is a number"
    );
  });

  test("url", async function (assert) {
    let errors = await new Validator("A", {
      url: {},
    }).validate();

    assert.deepEqual(
      errors,
      [i18n("form_kit.errors.invalid_url")],
      "it returns an error when the value is not a valid URL"
    );

    errors = await new Validator("http://www.discourse.org", {
      url: {},
    }).validate();
    assert.deepEqual(
      errors,
      [],
      "it returns no errors when the value is a valid URL"
    );
  });

  test("accepted", async function (assert) {
    let errors = await new Validator("A", {
      accepted: {},
    }).validate();
    assert.deepEqual(
      errors,
      [i18n("form_kit.errors.not_accepted")],
      "it returns an error when the value is not accepted"
    );

    errors = await new Validator(1, { accepted: {} }).validate();
    assert.deepEqual(
      errors,
      [],
      "it returns no errors when the value is truthy"
    );

    errors = await new Validator(true, { accepted: {} }).validate();
    assert.deepEqual(
      errors,
      [],
      "it returns no errors when the value is truthy"
    );

    errors = await new Validator("true", { accepted: {} }).validate();
    assert.deepEqual(
      errors,
      [],
      "it returns no errors when the value is truthy"
    );

    errors = await new Validator("on", { accepted: {} }).validate();
    assert.deepEqual(
      errors,
      [],
      "it returns no errors when the value is truthy"
    );

    errors = await new Validator("yes", { accepted: {} }).validate();
    assert.deepEqual(
      errors,
      [],
      "it returns no errors when the value is truthy"
    );
  });

  test("required", async function (assert) {
    let errors = await new Validator(" ", {
      required: { trim: true },
    }).validate("input-text");

    assert.deepEqual(
      errors,
      [i18n("form_kit.errors.required")],
      "it returns an error when the value is empty spaces with trim"
    );

    errors = await new Validator(" ", {
      required: { trim: false },
    }).validate("input-text");

    assert.deepEqual(
      errors,
      [],
      "it returns no errors when the value is empty spaces without trim"
    );

    errors = await new Validator(undefined, {
      required: {},
    }).validate("input-number");
    assert.deepEqual(
      errors,
      [i18n("form_kit.errors.required")],
      "it returns an error when the value is undefined"
    );

    errors = await new Validator("A", {
      required: {},
    }).validate("input-number");
    assert.deepEqual(
      errors,
      [i18n("form_kit.errors.required")],
      "it returns an error when the value is not a number"
    );

    errors = await new Validator(false, {
      required: {},
    }).validate("question");
    assert.deepEqual(
      errors,
      [],
      "it returns no errors when the value is false"
    );

    errors = await new Validator(true, {
      required: {},
    }).validate("question");
    assert.deepEqual(errors, [], "it returns no errors when the value is true");

    errors = await new Validator(undefined, {
      required: {},
    }).validate("question");
    assert.deepEqual(
      errors,
      [i18n("form_kit.errors.required")],
      "it returns an error when the value is undefined"
    );

    errors = await new Validator(undefined, {
      required: {},
    }).validate("menu");
    assert.deepEqual(
      errors,
      [i18n("form_kit.errors.required")],
      "it returns an error when the value is undefined"
    );

    errors = await new Validator(0, {
      required: {},
    }).validate("xxx");
    assert.deepEqual(errors, [], "it returns no error when the value is 0");
  });
});
