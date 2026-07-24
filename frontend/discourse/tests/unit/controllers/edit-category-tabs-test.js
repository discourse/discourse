import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, {
  parsePostData,
} from "discourse/tests/helpers/create-pretender";

function fakeFormApi(siteTexts = {}) {
  const data = { site_texts: { ...siteTexts } };
  return {
    isDirty: false,
    get(name) {
      return name.split(".").reduce((value, part) => value?.[part], data);
    },
    set(name, value) {
      const parts = name.split(".");
      let target = data;
      while (parts.length > 1) {
        target = target[parts.shift()];
      }
      target[parts[0]] = value;
    },
    commitField() {},
  };
}

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

  test("saving writes customizable text for every edited language at once", async function (assert) {
    const key = "js.solved.shared_issue.label";
    const name = "st_label";

    this.controller.model = {
      id: 1,
      categoryTypes: {
        support: { configuration_schema: { site_texts: [{ key, name }] } },
      },
    };

    this.controller.siteTextsLocale = "en";
    this.controller.siteTextOriginals = { en: { [name]: "Mark as similar" } };
    this.controller.siteTextEdits = { en: { [name]: "Mark as similar" } };
    this.controller.formApi = fakeFormApi({ [name]: "Mark as similar" });

    pretender.get(`/admin/customize/site_texts/${key}.json`, () => [
      200,
      { "Content-Type": "application/json" },
      JSON.stringify({ site_text: { id: key, value: "Moi aussi" } }),
    ]);

    const saved = [];
    pretender.put(`/admin/customize/site_texts/${key}`, (request) => {
      saved.push({
        locale: request.queryParams.locale,
        value: parsePostData(request.requestBody).site_text.value,
      });
      return [
        200,
        { "Content-Type": "application/json" },
        JSON.stringify({ site_text: {} }),
      ];
    });

    // Edit English, switch to French, edit French, then save once.
    this.controller.formApi.set(`site_texts.${name}`, "Me too");
    await this.controller.switchSiteTextsLocale("fr");
    this.controller.formApi.set(`site_texts.${name}`, "Moi aussi (edited)");

    const changed = await this.controller._saveSiteTexts();

    assert.true(changed, "reports that customizable text changed");
    assert.deepEqual(
      saved.sort((a, b) => a.locale.localeCompare(b.locale)),
      [
        { locale: "en", value: "Me too" },
        { locale: "fr", value: "Moi aussi (edited)" },
      ],
      "writes the edited value for both languages in a single save"
    );
  });
});
