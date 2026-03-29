import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Controller | edit-category-tabs", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.controller = getOwner(this).lookup("controller:edit-category/tabs");
  });

  test("registerAfterReset stores callbacks", function (assert) {
    let called = false;
    this.controller.registerAfterReset(() => (called = true));

    assert.strictEqual(
      this.controller.afterResetCallbacks.length,
      1,
      "callback is registered"
    );

    this.controller.onFormReset();
    assert.true(called, "callback is invoked on form reset");
  });

  test("onFormReset invokes all registered callbacks", function (assert) {
    const log = [];
    this.controller.registerAfterReset(() => log.push("a"));
    this.controller.registerAfterReset(() => log.push("b"));

    this.controller.onFormReset();

    assert.deepEqual(log, ["a", "b"], "all callbacks are invoked in order");
  });

  test("validateForm delegates to registered validators", function (assert) {
    this.controller.siteSettings = {
      enable_simplified_category_creation: true,
    };
    this.controller.selectedTab = "general";

    const validatorLog = [];
    this.controller.registerValidator((data, { addError, removeError }) => {
      validatorLog.push({
        data,
        hasAddError: !!addError,
        hasRemoveError: !!removeError,
      });
    });

    const data = { name: "Test" };
    const addError = () => {};
    const removeError = () => {};

    this.controller.validateForm(data, { addError, removeError });

    assert.strictEqual(validatorLog.length, 1, "validator was called");
    assert.deepEqual(
      validatorLog[0].data,
      data,
      "validator receives the form data"
    );
    assert.true(
      validatorLog[0].hasAddError,
      "validator receives addError helper"
    );
    assert.true(
      validatorLog[0].hasRemoveError,
      "validator receives removeError helper"
    );
  });

  test("validateForm passes removeError to validators", function (assert) {
    this.controller.siteSettings = {
      enable_simplified_category_creation: true,
    };
    this.controller.selectedTab = "general";

    let removedField;
    this.controller.registerValidator((_data, { removeError }) => {
      removeError("myField");
    });

    const addError = () => {};
    const removeError = (name) => (removedField = name);

    this.controller.validateForm({ name: "Test" }, { addError, removeError });

    assert.strictEqual(
      removedField,
      "myField",
      "validator can call removeError"
    );
  });
});
