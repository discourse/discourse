import { click, fillIn, render, typeIn } from "@ember/test-helpers";
import { module, skip, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import SiteSettingComponent from "admin/components/site-setting";
import SiteSetting from "admin/models/site-setting";

module("Integration | Component | site-setting", function (hooks) {
  setupRenderingTest(hooks);

  test("displays host-list setting value", async function (assert) {
    const self = this;

    this.set(
      "setting",
      SiteSetting.create({
        setting: "blocked_onebox_domains",
        value: "a.com|b.com",
        type: "host_list",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{self.setting}} /></template>
    );

    assert.dom(".formatted-selection").hasText("a.com, b.com");
  });

  test("Error response with html_message is rendered as HTML", async function (assert) {
    const self = this;

    this.set(
      "setting",
      SiteSetting.create({
        setting: "test_setting",
        value: "",
        type: "input-setting-string",
      })
    );

    const message = "<h1>Unable to update site settings</h1>";

    pretender.put("/admin/site_settings/test_setting", () => {
      return response(422, { html_message: true, errors: [message] });
    });

    await render(
      <template><SiteSettingComponent @setting={{self.setting}} /></template>
    );
    await fillIn(".setting input", "value");
    await click(".setting .d-icon-check");

    assert.dom(".validation-error").includesHtml(message);
  });

  test("Error response without html_message is not rendered as HTML", async function (assert) {
    const self = this;

    this.set(
      "setting",
      SiteSetting.create({
        setting: "test_setting",
        value: "",
        type: "input-setting-string",
      })
    );

    const message = "<h1>Unable to update site settings</h1>";

    pretender.put("/admin/site_settings/test_setting", () => {
      return response(422, { errors: [message] });
    });

    await render(
      <template><SiteSettingComponent @setting={{self.setting}} /></template>
    );
    await fillIn(".setting input", "value");
    await click(".setting .d-icon-check");

    assert.dom(".validation-error h1").doesNotExist();
  });

  test("displays file types list setting", async function (assert) {
    const self = this;

    this.set(
      "setting",
      SiteSetting.create({
        setting: "theme_authorized_extensions",
        value: "jpg|jpeg|png",
        type: "file_types_list",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{self.setting}} /></template>
    );

    assert.dom(".formatted-selection").hasText("jpg, jpeg, png");

    await click(".file-types-list__button.image");

    assert
      .dom(".formatted-selection")
      .hasText("jpg, jpeg, png, gif, heic, heif, webp, avif, svg");

    await click(".file-types-list__button.image");

    assert
      .dom(".formatted-selection")
      .hasText("jpg, jpeg, png, gif, heic, heif, webp, avif, svg");
  });

  // Skipping for now because ember-test-helpers doesn't check for defaultPrevented when firing that event chain
  skip("prevents decimal in integer setting input", async function (assert) {
    const self = this;

    this.set(
      "setting",
      SiteSetting.create({
        setting: "suggested_topics_unread_max_days_old",
        value: "",
        type: "integer",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{self.setting}} /></template>
    );
    await typeIn(".input-setting-integer", "90,5", { delay: 1000 });
    assert.dom(".input-setting-integer").hasValue("905");
  });

  test("does not consider an integer setting overridden if the value is the same as the default", async function (assert) {
    const self = this;

    this.set(
      "setting",
      SiteSetting.create({
        setting: "suggested_topics_unread_max_days_old",
        value: "99",
        default: "99",
        type: "integer",
      })
    );
    await render(
      <template><SiteSettingComponent @setting={{self.setting}} /></template>
    );
    await fillIn(".input-setting-integer", "90");
    assert.dom(".input-setting-integer").hasValue("90");
    await fillIn(".input-setting-integer", "99");
    assert
      .dom("[data-setting='suggested_topics_unread_max_days_old']")
      .hasNoClass("overridden");
  });

  test("Input for secret site setting is hidden by default", async function (assert) {
    const self = this;

    this.set(
      "setting",
      SiteSetting.create({
        setting: "test_setting",
        secret: true,
        value: "foo",
      })
    );
    await render(
      <template><SiteSettingComponent @setting={{self.setting}} /></template>
    );
    assert.dom(".input-setting-string").hasAttribute("type", "password");
    assert.dom(".setting-toggle-secret svg").hasClass("d-icon-far-eye");
    await click(".setting-toggle-secret");
    assert.dom(".input-setting-string").hasAttribute("type", "text");
    assert.dom(".setting-toggle-secret svg").hasClass("d-icon-far-eye-slash");
    await click(".setting-toggle-secret");
    assert.dom(".input-setting-string").hasAttribute("type", "password");
    assert.dom(".setting-toggle-secret svg").hasClass("d-icon-far-eye");
  });
});

module(
  "Integration | Component | site-setting | file_size_restriction type",
  function (hooks) {
    setupRenderingTest(hooks);

    test("shows the reset button when the value has been changed from the default", async function (assert) {
      const self = this;

      this.set(
        "setting",
        SiteSetting.create({
          setting: "max_image_size_kb",
          value: "2048",
          default: "1024",
          min: 512,
          max: 4096,
          type: "file_size_restriction",
        })
      );

      await render(
        <template><SiteSettingComponent @setting={{self.setting}} /></template>
      );
      assert.dom(".setting-controls__undo").exists("reset button is shown");
    });

    test("doesn't show the reset button when the value is the same as the default", async function (assert) {
      const self = this;

      this.set(
        "setting",
        SiteSetting.create({
          setting: "max_image_size_kb",
          value: "1024",
          default: "1024",
          min: 512,
          max: 4096,
          type: "file_size_restriction",
        })
      );

      await render(
        <template><SiteSettingComponent @setting={{self.setting}} /></template>
      );
      assert
        .dom(".setting-controls__undo")
        .doesNotExist("reset button is not shown");
    });

    test("shows validation error when the value exceeds the max limit", async function (assert) {
      const self = this;

      this.set(
        "setting",
        SiteSetting.create({
          setting: "max_image_size_kb",
          value: "1024",
          default: "1024",
          min: 512,
          max: 4096,
          type: "file_size_restriction",
        })
      );

      await render(
        <template><SiteSettingComponent @setting={{self.setting}} /></template>
      );
      await fillIn(".file-size-input", "5000");

      assert.dom(".validation-error").hasText(
        i18n("file_size_input.error.size_too_large", {
          provided_file_size: "4.9 GB",
          max_file_size: "4 MB",
        }),
        "validation error message is shown"
      );
      assert.dom(".setting-controls__cancel").doesNotHaveAttribute("disabled");
    });

    test("shows validation error when the value is below the min limit", async function (assert) {
      const self = this;

      this.set(
        "setting",
        SiteSetting.create({
          setting: "max_image_size_kb",
          value: "1000",
          default: "1024",
          min: 512,
          max: 4096,
          type: "file_size_restriction",
        })
      );

      await render(
        <template><SiteSettingComponent @setting={{self.setting}} /></template>
      );
      await fillIn(".file-size-input", "100");

      assert.dom(".validation-error").hasText(
        i18n("file_size_input.error.size_too_small", {
          provided_file_size: "100 KB",
          min_file_size: "512 KB",
        }),
        "validation error message is shown"
      );
      assert.dom(".setting-controls__cancel").doesNotHaveAttribute("disabled");
    });

    test("cancelling pending changes resets the value and removes validation error", async function (assert) {
      const self = this;

      this.set(
        "setting",
        SiteSetting.create({
          setting: "max_image_size_kb",
          value: "1000",
          default: "1024",
          min: 512,
          max: 4096,
          type: "file_size_restriction",
        })
      );

      await render(
        <template><SiteSettingComponent @setting={{self.setting}} /></template>
      );

      await fillIn(".file-size-input", "100");
      assert.dom(".validation-error").hasNoClass("hidden");

      await click(".setting-controls__cancel");
      assert
        .dom(".file-size-input")
        .hasValue("1000", "the value resets to the saved value");
      assert.dom(".validation-error").hasClass("hidden");
    });

    test("resetting to the default value changes the content of input field", async function (assert) {
      const self = this;

      this.set(
        "setting",
        SiteSetting.create({
          setting: "max_image_size_kb",
          value: "1000",
          default: "1024",
          min: 512,
          max: 4096,
          type: "file_size_restriction",
        })
      );

      await render(
        <template><SiteSettingComponent @setting={{self.setting}} /></template>
      );
      assert
        .dom(".file-size-input")
        .hasValue("1000", "the input field contains the custom value");

      await click(".setting-controls__undo");
      assert
        .dom(".file-size-input")
        .hasValue("1024", "the input field now contains the default value");

      assert
        .dom(".setting-controls__undo")
        .doesNotExist("the reset button is not shown");
      assert.dom(".setting-controls__ok").exists("the save button is shown");
      assert
        .dom(".setting-controls__cancel")
        .exists("the cancel button is shown");
    });

    test("resetting to the default value changes the content of checkbox field", async function (assert) {
      const self = this;

      this.set(
        "setting",
        SiteSetting.create({
          setting: "test_setting",
          value: "true",
          default: "false",
          type: "bool",
        })
      );

      await render(
        <template><SiteSettingComponent @setting={{self.setting}} /></template>
      );
      assert
        .dom("input[type=checkbox]")
        .isChecked("the checkbox contains the custom value");

      await click(".setting-controls__undo");
      assert
        .dom("input[type=checkbox]")
        .isNotChecked("the checkbox now contains the default value");

      assert
        .dom(".setting-controls__undo")
        .doesNotExist("the reset button is not shown");
      assert.dom(".setting-controls__ok").exists("the save button is shown");
      assert
        .dom(".setting-controls__cancel")
        .exists("the cancel button is shown");
    });

    test("clearing the input field keeps the cancel button and the validation error shown", async function (assert) {
      const self = this;

      this.set(
        "setting",
        SiteSetting.create({
          setting: "max_image_size_kb",
          value: "1000",
          default: "1024",
          min: 512,
          max: 4096,
          type: "file_size_restriction",
        })
      );

      await render(
        <template><SiteSettingComponent @setting={{self.setting}} /></template>
      );

      await fillIn(".file-size-input", "100");
      assert.dom(".validation-error").hasNoClass("hidden");

      await fillIn(".file-size-input", "");
      assert.dom(".validation-error").hasNoClass("hidden");
      assert.dom(".setting-controls__ok").exists("the save button is shown");
      assert
        .dom(".setting-controls__cancel")
        .exists("the cancel button is shown");
      assert.dom(".setting-controls__cancel").doesNotHaveAttribute("disabled");

      await click(".setting-controls__cancel");
      assert.dom(".file-size-input").hasValue("1000");
      assert.dom(".validation-error").hasClass("hidden");
      assert
        .dom(".setting-controls__ok")
        .doesNotExist("the save button is not shown");
      assert
        .dom(".setting-controls__cancel")
        .doesNotExist("the cancel button is shown");
    });
  }
);

module(
  "Integration | Component | site-setting | font-list type",
  function (hooks) {
    setupRenderingTest(hooks);

    const fonts = [
      { value: "arial", name: "Arial" },
      { value: "times_new_roman", name: "Times New Roman" },
    ];

    test("base_font sets body-font-X classNames on each field choice", async function (assert) {
      const self = this;

      this.set(
        "setting",
        SiteSetting.create({
          category: "",
          choices: fonts,
          default: "",
          description: "Base font",
          placeholder: null,
          preview: null,
          secret: false,
          setting: "base_font",
          type: "font_list",
          value: "arial",
        })
      );

      await render(
        <template><SiteSettingComponent @setting={{self.setting}} /></template>
      );
      const fontSelector = selectKit(".font-selector");
      await fontSelector.expand();

      fonts.forEach((choice) => {
        const fontClass = `body-font-${choice.value.replace(/_/g, "-")}`;
        assert.true(
          fontSelector.rowByValue(choice.value).hasClass(fontClass),
          `has ${fontClass} CSS class`
        );
      });
    });

    test("heading_font sets heading-font-X classNames on each field choice", async function (assert) {
      const self = this;

      this.set(
        "setting",
        SiteSetting.create({
          category: "",
          choices: fonts,
          default: "",
          description: "Heading font",
          placeholder: null,
          preview: null,
          secret: false,
          setting: "heading_font",
          type: "font_list",
          value: "arial",
        })
      );

      await render(
        <template><SiteSettingComponent @setting={{self.setting}} /></template>
      );
      const fontSelector = selectKit(".font-selector");
      await fontSelector.expand();

      fonts.forEach((choice) => {
        const fontClass = `heading-font-${choice.value.replace(/_/g, "-")}`;
        assert.true(
          fontSelector.rowByValue(choice.value).hasClass(fontClass),
          `has ${fontClass} CSS class`
        );
      });
    });
  }
);
