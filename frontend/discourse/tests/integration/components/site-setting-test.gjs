import { click, fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteSettingComponent from "discourse/admin/components/site-setting";
import SiteSetting from "discourse/admin/models/site-setting";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

module("Integration | Component | SiteSetting", function (hooks) {
  setupRenderingTest(hooks);

  test("displays host-list setting value", async function (assert) {
    this.set(
      "setting",
      SiteSetting.create({
        setting: "blocked_onebox_domains",
        value: "a.com|b.com",
        type: "host_list",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    assert.dom(".formatted-selection").hasText("a.com, b.com");
  });

  test("error response with html_message is rendered as HTML", async function (assert) {
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
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );
    await fillIn(".setting input", "value");
    await click(".setting .d-icon-check");

    assert.dom(".validation-error").includesHtml(message);
  });

  test("error response without html_message is not rendered as HTML", async function (assert) {
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
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );
    await fillIn(".setting input", "value");
    await click(".setting .d-icon-check");

    assert.dom(".validation-error h1").doesNotExist();
  });

  test("displays file types list setting", async function (assert) {
    this.set(
      "setting",
      SiteSetting.create({
        setting: "theme_authorized_extensions",
        value: "jpg|jpeg|png",
        type: "file_types_list",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
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

  test("prevents decimal in integer setting input", async function (assert) {
    const setting = SiteSetting.create({
      setting: "suggested_topics_unread_max_days_old",
      value: "",
      type: "integer",
    });

    await render(
      <template><SiteSettingComponent @setting={{setting}} /></template>
    );

    const input = document.querySelector(".input-setting-integer");
    const isPrevented = (key) => {
      const event = new KeyboardEvent("keydown", {
        key,
        bubbles: true,
        cancelable: true,
      });
      input.dispatchEvent(event);
      return event.defaultPrevented;
    };

    assert.true(isPrevented(","), "prevents ,");
    assert.true(isPrevented("."), "prevents .");
    assert.false(isPrevented("9"), "allows 9");
  });

  test("does not consider an integer setting overridden if the value is the same as the default", async function (assert) {
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
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );
    await fillIn(".input-setting-integer", "90");
    assert.dom(".input-setting-integer").hasValue("90");
    await fillIn(".input-setting-integer", "99");
    assert
      .dom("[data-setting='suggested_topics_unread_max_days_old']")
      .hasNoClass("overridden");
  });

  test("Input for secret site setting is hidden by default", async function (assert) {
    this.set(
      "setting",
      SiteSetting.create({
        setting: "test_setting",
        secret: true,
        value: "foo",
      })
    );
    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
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

  test("shows link to the staff action logs for the setting on hover", async function (assert) {
    this.set(
      "setting",
      SiteSetting.create({
        setting: "enable_badges",
        value: "false",
        default: "true",
        type: "bool",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    await triggerEvent("[data-setting='enable_badges']", "mouseenter");

    assert
      .dom("[data-setting='enable_badges'] .staff-action-log-link")
      .exists()
      .hasAttribute(
        "href",
        `/admin/logs/staff_action_logs?filters=${encodeURIComponent(JSON.stringify({ subject: "enable_badges", action_name: "change_site_setting" }))}&force_refresh=true`
      );
  });

  test("Shows update status for default_categories_* site settings", async function (assert) {
    this.set(
      "setting",
      SiteSetting.create({
        setting: "default_categories_test",
        value: "",
        type: "category_list",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    await publishToMessageBus("/site_setting/default_categories_test/process", {
      status: "enqueued",
    });

    assert.dom(".desc.site-setting").hasTextContaining("Update in progress");

    await publishToMessageBus("/site_setting/default_categories_test/process", {
      status: "enqueued",
      progress: "10/100",
    });

    assert.dom(".desc.site-setting").hasTextContaining("Update in progress");
    assert.dom(".desc.site-setting").hasTextContaining("10/100");

    await publishToMessageBus("/site_setting/default_categories_test/process", {
      status: "completed",
    });
    assert.dom(".desc.site-setting").hasTextContaining("Update completed");
  });

  test("Shows update status for default_tags_* site settings", async function (assert) {
    this.set(
      "setting",
      SiteSetting.create({
        setting: "default_tags_test",
        value: "",
        type: "tag_list",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    await publishToMessageBus("/site_setting/default_tags_test/process", {
      status: "enqueued",
    });
    assert.dom(".desc.site-setting").hasTextContaining("Update in progress");

    await publishToMessageBus("/site_setting/default_tags_test/process", {
      status: "enqueued",
      progress: "10/100",
    });

    assert.dom(".desc.site-setting").hasTextContaining("Update in progress");
    assert.dom(".desc.site-setting").hasTextContaining("10/100");

    await publishToMessageBus("/site_setting/default_tags_test/process", {
      status: "completed",
    });
    assert.dom(".desc.site-setting").hasTextContaining("Update completed");
  });

  test("Doesn't shows update status for other site settings besides default_tags_test or default_categories_test", async function (assert) {
    this.set(
      "setting",
      SiteSetting.create({
        setting: "default_test",
        value: "",
        type: "tag_list",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    await publishToMessageBus("/site_setting/default_tags_test/process", {
      status: "enqueued",
    });
    assert.dom(".desc.site-setting").doesNotExist();

    await publishToMessageBus("/site_setting/default_tags_test/process", {
      status: "completed",
    });
    assert.dom(".desc.site-setting").doesNotExist();
  });

  test("doesn't display the save/cancel buttons when the selected value is returned to the current value", async function (assert) {
    const setting = SiteSetting.create({
      setting: "some_enum",
      value: "2",
      default: "1",
      type: "enum",
      valid_values: [
        { name: "Option 1", value: 1 },
        { name: "Option 2", value: 2 },
      ],
    });

    await render(
      <template><SiteSettingComponent @setting={{setting}} /></template>
    );

    const selector = selectKit(".select-kit");

    await selector.expand();
    await selector.selectRowByValue("1");

    assert
      .dom(".setting-controls__ok")
      .exists("the save button is shown after changing the value");
    assert
      .dom(".setting-controls__cancel")
      .exists("the cancel button is shown after changing the value");

    await selector.expand();
    await selector.selectRowByValue("2");

    assert
      .dom(".setting-controls__ok")
      .doesNotExist(
        "the save button is not shown after changing the value back to the original"
      );
    assert
      .dom(".setting-controls__cancel")
      .doesNotExist(
        "the cancel button is not shown after changing the value back to the original"
      );
  });
});

module(
  "Integration | Component | SiteSetting | Themeable Settings",
  function (hooks) {
    setupRenderingTest(hooks);

    test("disables input for themeable site settings", async function (assert) {
      this.site = this.container.lookup("service:site");
      this.site.set("user_themes", [
        { theme_id: 5, default: true, name: "Default Theme" },
      ]);

      this.set(
        "setting",
        SiteSetting.create({
          setting: "test_themeable_setting",
          value: "test value",
          type: "string",
          themeable: true,
        })
      );

      await render(
        <template><SiteSettingComponent @setting={{this.setting}} /></template>
      );

      assert.dom(".input-setting-string").hasAttribute("disabled", "");
      assert
        .dom(".setting-controls__ok")
        .doesNotExist("save button is not shown");
    });

    test("shows warning text for themeable site settings", async function (assert) {
      this.site = this.container.lookup("service:site");
      this.site.set("user_themes", [
        { theme_id: 5, default: true, name: "Default Theme" },
      ]);

      this.set(
        "setting",
        SiteSetting.create({
          setting: "test_themeable_setting",
          value: "test value",
          type: "string",
          themeable: true,
        })
      );

      await render(
        <template><SiteSettingComponent @setting={{this.setting}} /></template>
      );

      assert
        .dom(".setting-theme-warning")
        .exists("warning wrapper is displayed");

      assert
        .dom(".setting-theme-warning__text")
        .exists("warning text element is displayed");

      const expectedText = i18n(
        "admin.theme_site_settings.site_setting_warning",
        {
          basePath: "",
          defaultThemeName: "Default Theme",
          defaultThemeId: 5,
        }
      );

      assert.dom(".setting-theme-warning__text").includesHtml(expectedText);
    });

    test("shows notice for settings that depend on another setting", async function (assert) {
      this.set(
        "setting",
        SiteSetting.create({
          setting: "dependent_setting",
          value: "1",
          type: "integer",
          depends_on: ["parent_setting"],
          depends_on_humanized_names: ["Parent setting"],
        })
      );

      await render(
        <template><SiteSettingComponent @setting={{this.setting}} /></template>
      );

      assert
        .dom(".setting-depends-on-notice")
        .exists("notice wrapper is displayed");
      assert
        .dom(".setting-depends-on-notice__text")
        .includesText(
          "This setting is only applied when Parent setting is enabled"
        );
      assert
        .dom(".setting-depends-on-notice__text a")
        .hasAttribute(
          "href",
          "/admin/site_settings/category/all_results?filter=parent_setting"
        )
        .hasText("Parent setting");
    });

    test("does not show the depends_on notice when setting has no dependencies", async function (assert) {
      this.set(
        "setting",
        SiteSetting.create({
          setting: "plain_setting",
          value: "1",
          type: "integer",
        })
      );

      await render(
        <template><SiteSettingComponent @setting={{this.setting}} /></template>
      );

      assert.dom(".setting-depends-on-notice").doesNotExist();
    });
  }
);

module(
  "Integration | Component | SiteSetting | file_size_restriction type",
  function (hooks) {
    setupRenderingTest(hooks);

    test("shows the reset button when the value has been changed from the default", async function (assert) {
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
        <template><SiteSettingComponent @setting={{this.setting}} /></template>
      );
      assert.dom(".setting-controls__undo").exists("reset button is shown");
    });

    test("doesn't show the reset button when the value is the same as the default", async function (assert) {
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
        <template><SiteSettingComponent @setting={{this.setting}} /></template>
      );
      assert
        .dom(".setting-controls__undo")
        .doesNotExist("reset button is not shown");
    });

    test("shows validation error when the value exceeds the max limit", async function (assert) {
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
        <template><SiteSettingComponent @setting={{this.setting}} /></template>
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
        <template><SiteSettingComponent @setting={{this.setting}} /></template>
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
        <template><SiteSettingComponent @setting={{this.setting}} /></template>
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
        <template><SiteSettingComponent @setting={{this.setting}} /></template>
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
        <template><SiteSettingComponent @setting={{this.setting}} /></template>
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
        <template><SiteSettingComponent @setting={{this.setting}} /></template>
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
  "Integration | Component | SiteSetting | font-list type",
  function (hooks) {
    setupRenderingTest(hooks);

    const fonts = [
      { value: "arial", name: "Arial" },
      { value: "times_new_roman", name: "Times New Roman" },
    ];

    test("base_font sets body-font-X classNames on each field choice", async function (assert) {
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
        <template><SiteSettingComponent @setting={{this.setting}} /></template>
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
        <template><SiteSettingComponent @setting={{this.setting}} /></template>
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

module(
  "Integration | Component | SiteSetting | depends_behavior: hidden",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.store = this.container.lookup("service:admin-site-setting-store");
      this.parent = SiteSetting.create({
        setting: "parent_flag",
        value: "false",
        default: "false",
        type: "bool",
      });
      this.child = SiteSetting.create({
        setting: "child_value",
        value: "5",
        default: "5",
        type: "integer",
        depends_on: ["parent_flag"],
        depends_behavior: "hidden",
      });
    });

    test("child renders disabled when parent is falsy", async function (assert) {
      this.store.register([this.parent, this.child]);

      await render(
        <template><SiteSettingComponent @setting={{this.child}} /></template>
      );

      assert
        .dom("[data-setting='child_value']")
        .hasClass("disabled-by-dependency");
      assert.dom(".input-setting-integer").hasAttribute("disabled");
    });

    test("child renders enabled when parent is truthy", async function (assert) {
      this.parent.value = "true";
      this.store.register([this.parent, this.child]);

      await render(
        <template><SiteSettingComponent @setting={{this.child}} /></template>
      );

      assert
        .dom("[data-setting='child_value']")
        .hasNoClass("disabled-by-dependency");
      assert.dom(".input-setting-integer").doesNotHaveAttribute("disabled");
    });

    test("toggling parent reactively flips child disabled and latches revealed", async function (assert) {
      this.store.register([this.parent, this.child]);

      await render(
        <template>
          <SiteSettingComponent @setting={{this.parent}} />
          <SiteSettingComponent @setting={{this.child}} />
        </template>
      );

      assert.false(this.store.isRevealed(this.child));
      assert
        .dom("[data-setting='child_value']")
        .hasClass("disabled-by-dependency");

      await click("[data-setting='parent_flag'] input[type=checkbox]");
      assert.true(
        this.store.isRevealed(this.child),
        "revealed latched on toggle-on"
      );
      assert
        .dom("[data-setting='child_value']")
        .hasNoClass("disabled-by-dependency");

      await click("[data-setting='parent_flag'] input[type=checkbox]");
      assert.true(this.store.isRevealed(this.child), "revealed stays latched");
      assert
        .dom("[data-setting='child_value']")
        .hasClass("disabled-by-dependency", "disabled again, not re-hidden");
    });

    test("resetting parent to a truthy default latches revealed", async function (assert) {
      this.parent.default = "true";
      this.store.register([this.parent, this.child]);

      await render(
        <template>
          <SiteSettingComponent @setting={{this.parent}} />
          <SiteSettingComponent @setting={{this.child}} />
        </template>
      );

      await click("[data-setting='parent_flag'] .setting-controls__undo");

      assert.true(this.store.isRevealed(this.child));
      assert
        .dom("[data-setting='child_value']")
        .hasNoClass("disabled-by-dependency");
    });
  }
);
