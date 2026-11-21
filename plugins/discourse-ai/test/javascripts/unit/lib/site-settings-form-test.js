import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SiteSetting from "discourse/admin/models/site-setting";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  findSetting,
  isSettingVisible,
  saveSettings,
} from "discourse/plugins/discourse-ai/discourse/lib/site-settings-form";

function createSetting(attrs) {
  return SiteSetting.create({
    setting: attrs.setting,
    humanized_name: attrs.setting,
    description: "",
    type: "string",
    value: null,
    default: null,
    ...attrs,
  });
}

function trackRequests() {
  const requests = [];
  pretender.put("/admin/site_settings/:name", (request) => {
    requests.push([
      request.params.name,
      new URLSearchParams(request.requestBody).get(request.params.name),
    ]);
    return response({});
  });
  return requests;
}

function trackFormApi() {
  const api = {
    removedErrors: 0,
    errors: [],
    removeErrors() {
      api.removedErrors += 1;
    },
    addError(name, error) {
      api.errors.push([name, error]);
    },
  };
  return api;
}

module("Unit | Lib | site-settings-form", function (hooks) {
  setupTest(hooks);

  test("findSetting finds a setting by name", function (assert) {
    const settings = [
      createSetting({ setting: "first", value: "a" }),
      createSetting({ setting: "second", value: "b" }),
    ];

    assert.strictEqual(findSetting(settings, "second"), settings[1]);
    assert.strictEqual(findSetting(settings, "missing"), undefined);
  });

  test("isSettingVisible only hides settings declared as hidden dependencies", function (assert) {
    const settings = [
      createSetting({ setting: "parent", type: "bool", value: true }),
      createSetting({ setting: "always_visible", value: "" }),
      createSetting({
        setting: "hidden_child",
        depends_behavior: "hidden",
        depends_on: ["parent"],
      }),
      createSetting({
        setting: "choice_child",
        depends_behavior: "hidden",
        depends_on: ["parent"],
        depends_on_values: { parent: ["include", "exclude"] },
      }),
    ];

    assert.true(
      isSettingVisible(settings, settings[1], {}),
      "settings without a hidden dependency are visible"
    );
    assert.true(
      isSettingVisible(settings, settings[2], { parent: true }),
      "the form's unsaved parent value is used"
    );
    assert.false(
      isSettingVisible(settings, settings[2], { parent: false }),
      "an unsaved parent change hides the child"
    );
    assert.true(
      isSettingVisible(settings, settings[3], { parent: "include" }),
      "depends_on_values match by string"
    );
    assert.false(
      isSettingVisible(settings, settings[3], { parent: true }),
      "values outside depends_on_values hide the child"
    );
    assert.false(
      isSettingVisible(settings, undefined, {}),
      "a setting the page does not have is not visible"
    );
  });

  test("saveSettings saves changed settings in the declared order", async function (assert) {
    const requests = trackRequests();
    const settings = [
      createSetting({ setting: "second", value: "old" }),
      createSetting({ setting: "first", value: "old" }),
    ];
    const saved = [];

    const success = await saveSettings(
      settings,
      { first: "new", second: "new" },
      undefined,
      (name, value) => saved.push([name, value])
    );

    assert.true(success, "reports success");
    assert.deepEqual(
      requests,
      [
        ["second", "new"],
        ["first", "new"],
      ],
      "prerequisites are saved first regardless of form order"
    );
    assert.deepEqual(
      saved,
      [
        ["second", "new"],
        ["first", "new"],
      ],
      "reports each saved setting"
    );
    assert.strictEqual(
      settings[0].value,
      "new",
      "the saved value replaces the setting's value"
    );
  });

  test("saveSettings skips equal values in another representation", async function (assert) {
    const requests = trackRequests();
    const settings = [
      createSetting({ setting: "bool_true", type: "bool", value: true }),
      createSetting({ setting: "bool_false", type: "bool", value: false }),
      createSetting({ setting: "integer", type: "integer", value: 50 }),
      createSetting({ setting: "number_string", value: "50" }),
      createSetting({ setting: "empty", value: "" }),
    ];

    const success = await saveSettings(settings, {
      bool_true: true,
      bool_false: false,
      integer: "50",
      number_string: 50,
      empty: "",
    });

    assert.true(success, "reports success");
    assert.deepEqual(
      requests,
      [],
      "booleans, numbers and strings compare by their string form"
    );
  });

  test("saveSettings treats missing saved values as distinct", async function (assert) {
    const requests = trackRequests();
    const settings = [
      createSetting({ setting: "saved_null", value: null }),
      createSetting({ setting: "saved_undefined", value: undefined }),
      createSetting({ setting: "saved_null_string", value: "null" }),
    ];

    await saveSettings(settings, {
      saved_null: "null",
      saved_undefined: "undefined",
      saved_null_string: null,
    });

    assert.deepEqual(
      requests,
      [
        ["saved_null", "null"],
        ["saved_undefined", "undefined"],
        ["saved_null_string", ""],
      ],
      "a missing value does not match its literal string form"
    );
    assert.strictEqual(
      settings[2].value,
      null,
      "the submitted value replaces the setting's value"
    );
  });

  test("saveSettings ignores settings the form does not render", async function (assert) {
    const requests = trackRequests();
    const formApi = trackFormApi();
    const settings = [
      createSetting({ setting: "visible", value: "old" }),
      createSetting({ setting: "hidden", value: "old" }),
    ];

    const success = await saveSettings(
      settings,
      { visible: "new", hidden: "stale draft" },
      formApi,
      undefined,
      { isVisible: (setting) => setting.setting !== "hidden" }
    );

    assert.true(success, "nothing failed");
    assert.deepEqual(
      requests,
      [["visible", "new"]],
      "the hidden setting's draft value is never submitted"
    );
    assert.deepEqual(formApi.errors, [], "the hidden setting reports no error");
    assert.strictEqual(
      settings[1].value,
      "old",
      "the hidden setting keeps its saved value"
    );
  });

  test("saveSettings reports failures per setting and keeps going", async function (assert) {
    const requests = trackRequests();
    pretender.put("/admin/site_settings/broken", () => {
      requests.push(["broken", "1"]);
      return response(422, { errors: ["broken: is invalid"] });
    });
    const formApi = trackFormApi();
    const settings = [
      createSetting({
        setting: "broken",
        humanized_name: "Broken setting",
        value: "",
      }),
      createSetting({ setting: "working", value: "" }),
    ];

    const success = await saveSettings(
      settings,
      { broken: "1", working: "1" },
      formApi
    );

    assert.false(success, "reports the failure");
    assert.strictEqual(formApi.removedErrors, 1, "previous errors are cleared");
    assert.deepEqual(
      formApi.errors,
      [["broken", { title: "Broken setting", message: "is invalid" }]],
      "the server error is attached to the failing field without its prefix"
    );
    assert.deepEqual(
      requests,
      [
        ["broken", "1"],
        ["working", "1"],
      ],
      "later settings are still saved"
    );
  });
});
