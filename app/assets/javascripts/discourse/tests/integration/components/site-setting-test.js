import { click, fillIn, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { query } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | site-setting", function (hooks) {
  setupRenderingTest(hooks);

  test("displays host-list setting value", async function (assert) {
    this.set("setting", {
      setting: "blocked_onebox_domains",
      value: "a.com|b.com",
      type: "host_list",
    });

    await render(hbs`<SiteSetting @setting={{this.setting}} />`);

    assert.strictEqual(query(".formatted-selection").innerText, "a.com, b.com");
  });

  test("Error response with html_message is rendered as HTML", async function (assert) {
    this.set("setting", {
      setting: "test_setting",
      value: "",
      type: "input-setting-string",
    });

    const message = "<h1>Unable to update site settings</h1>";

    pretender.put("/admin/site_settings/test_setting", () => {
      return response(422, { html_message: true, errors: [message] });
    });

    await render(hbs`<SiteSetting @setting={{this.setting}} />`);
    await fillIn(query(".setting input"), "value");
    await click(query(".setting .d-icon-check"));

    assert.strictEqual(query(".validation-error h1").outerHTML, message);
  });

  test("Error response without html_message is not rendered as HTML", async function (assert) {
    this.set("setting", {
      setting: "test_setting",
      value: "",
      type: "input-setting-string",
    });

    const message = "<h1>Unable to update site settings</h1>";

    pretender.put("/admin/site_settings/test_setting", () => {
      return response(422, { errors: [message] });
    });

    await render(hbs`<SiteSetting @setting={{this.setting}} />`);
    await fillIn(query(".setting input"), "value");
    await click(query(".setting .d-icon-check"));

    assert.strictEqual(query(".validation-error h1"), null);
  });

  test("displays file types list setting", async function (assert) {
    this.set("setting", {
      setting: "theme_authorized_extensions",
      value: "jpg|jpeg|png",
      type: "file_types_list",
    });

    await render(hbs`<SiteSetting @setting={{this.setting}} />`);

    assert.strictEqual(
      query(".formatted-selection").innerText,
      "jpg, jpeg, png"
    );

    await click(query(".file-types-list__button.image"));

    assert.strictEqual(
      query(".formatted-selection").innerText,
      "jpg, jpeg, png, gif, heic, heif, webp, avif, svg"
    );

    await click(query(".file-types-list__button.image"));

    assert.strictEqual(
      query(".formatted-selection").innerText,
      "jpg, jpeg, png, gif, heic, heif, webp, avif, svg"
    );
  });
});
