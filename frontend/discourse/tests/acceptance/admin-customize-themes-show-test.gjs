import { click, currentURL, find, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Admin - Customize - Themes - Show", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/admin/themes", () => {
      return helper.response({
        themes: [
          {
            id: -1,
            name: "Foundation",
            description:
              "The classic Discourse theme that is well-suited to customization for your community’s specific needs.",
            created_at: "2025-06-11T23:50:31.187Z",
            updated_at: "2025-06-12T03:09:26.162Z",
            default: true,
            component: false,
            color_scheme_id: 6,
            user_selectable: false,
            auto_update: false,
            remote_theme_id: null,
            settings: [],
            supported: true,
            enabled: true,
            theme_fields: [
              {
                name: "screenshot_light",
                target: "common",
                value: "",
                type_id: 7,
                upload_id: 83,
                url: "/uploads/default/original/1X/f8a61b9a0bfac672daec9e401787812f8c5e28df.png",
                filename: "light.png",
              },
              {
                name: "screenshot_dark",
                target: "common",
                value: "",
                type_id: 7,
                upload_id: 84,
                url: "/uploads/default/original/1X/783d7817fd5e44b15d3532ffb13d2f70174a039f.png",
                filename: "dark.png",
              },
              {
                name: "email_header",
                target: "email_header",
                value: "<header>Email header content</header>",
                type_id: 0,
              },
              {
                name: "email_footer",
                target: "email_footer",
                value: "<footer>Email footer content</footer>",
                type_id: 0,
              },
              {
                name: "en",
                target: "translations",
                value:
                  'en:\n  theme_metadata:\n    description: "The classic Discourse theme that is well-suited to customization for your community’s specific needs."\n',
                type_id: 5,
              },
            ],
            screenshot_light_url:
              "/uploads/default/original/1X/f8a61b9a0bfac672daec9e401787812f8c5e28df.png",
            system: true,
            color_scheme: null,
            user: {
              id: -1,
              username: "system",
              name: "system",
              avatar_template: "/images/discourse-logo-sketch-small.png",
              title: null,
            },
            child_themes: [],
            parent_themes: [],
            remote_theme: null,
            translations: [
              {
                key: "theme_metadata.description",
                value: "The classic Discourse theme...",
                default: "The classic Discourse theme...",
              },
            ],
          },
          {
            id: 42,
            name: "Git theme",
            created_at: "2025-06-11T23:50:31.187Z",
            updated_at: "2025-06-12T03:09:26.162Z",
            default: false,
            component: false,
            user_selectable: false,
            auto_update: false,
            remote_theme_id: 42,
            settings: [],
            supported: true,
            enabled: true,
            theme_fields: [],
            system: false,
            color_scheme: null,
            user: {
              id: -1,
              username: "system",
              name: "system",
              avatar_template: "/images/discourse-logo-sketch-small.png",
              title: null,
            },
            child_themes: [],
            parent_themes: [],
            remote_theme: {
              id: 42,
              remote_url: "https://github.com/example/theme.git",
              remote_version: "def456",
              local_version: "abc123",
              commits_behind: 2,
              branch: "main",
              is_git: true,
              local_compat_ref: "d-compat/2026.5",
              remote_compat_ref: "d-compat/2026.5",
            },
            translations: [],
          },
        ],
      });
    });

    server.get("/admin/config/customize/themes", () => {
      return helper.response({ themes: [] });
    });
  });

  test("admin-customize-theme-included-components-setting plugin outlet", async function (assert) {
    withPluginApi((api) => {
      api.renderInOutlet(
        "admin-customize-theme-included-components-setting",
        <template>
          <p class="custom-element-in-place-of-included-components">
            This is a custom element that replaces the included components
            setting.
          </p>
        </template>
      );
    });

    await visit("/admin/customize/themes/-1");
    assert
      .dom(".included-components-setting .select-kit")
      .doesNotExist(
        "the included components setting is replaced by a custom element"
      );
    assert
      .dom(
        ".included-components-setting .custom-element-in-place-of-included-components"
      )
      .hasText(
        "This is a custom element that replaces the included components setting."
      );
  });

  test("admin-customize-theme-translation-selector plugin outlet exposes the theme", async function (assert) {
    withPluginApi((api) => {
      api.renderInOutlet(
        "admin-customize-theme-translation-selector",
        <template>
          <span class="theme-translation-outlet-test">
            theme:{{@outletArgs.theme.id}}
          </span>
        </template>
      );
    });

    await visit("/admin/customize/themes/-1");
    assert
      .dom(".translation-selector-container .theme-translation-outlet-test")
      .hasText(
        "theme:-1",
        "the theme id is exposed via outletArgs on the translation selector outlet"
      );
  });

  test("shows email fields in a separate advanced editor row", async function (assert) {
    await visit("/admin/customize/themes/-1/common/scss/edit");

    assert
      .dom(".theme-editor__advanced-fields")
      .doesNotExist("email fields are hidden by default");

    await click(".d-toggle-switch__checkbox");

    assert
      .dom(".theme-editor__fields")
      .doesNotIncludeText(
        "Email header",
        "email fields are excluded from the standard field row"
      );
    assert
      .dom(".edit-main-nav")
      .doesNotIncludeText(
        "Email header",
        "email fields are excluded from the target row"
      );
    assert
      .dom(".theme-editor__advanced-fields")
      .includesText(
        "Email header",
        "the advanced row includes the email header"
      )
      .includesText(
        "Email footer",
        "the advanced row includes the email footer"
      );
  });

  test("handles direct links to advanced email fields", async function (assert) {
    this.siteSettings.enable_email_theme_header_and_footer = true;

    await visit("/admin/customize/themes/-1/email_header/email_header/edit");

    assert
      .dom(".d-toggle-switch__checkbox")
      .hasAttribute(
        "aria-checked",
        "true",
        "advanced mode is shown as enabled"
      );
    assert
      .dom(
        '.edit-main-nav a[href="/admin/customize/themes/-1/common/scss/edit"]'
      )
      .exists("the standard target row links to a valid standard field");
    assert
      .dom(".theme-editor__advanced-fields")
      .includesText("Email header", "the advanced row remains visible");
    assert
      .dom(".theme-editor__email-disabled-notice")
      .doesNotExist(
        "the disabled notice is hidden when email fields are enabled"
      );
    assert
      .dom(".ace-wrapper")
      .hasAttribute(
        "data-disabled",
        "false",
        "the email field remains editable"
      );

    await click(".d-toggle-switch__checkbox");

    assert.strictEqual(
      currentURL(),
      "/admin/customize/themes/-1/common/scss/edit",
      "disabling advanced mode leaves the email editor"
    );
    assert
      .dom(".theme-editor__advanced-fields")
      .doesNotExist("email fields are hidden after disabling advanced mode");
  });

  test("preserves email editor content mode and advanced navigation", async function (assert) {
    this.siteSettings.enable_email_theme_header_and_footer = true;

    await visit("/admin/customize/themes/-1/email_header/email_header/edit");

    let editor = find(".theme-editor__code").aceEditor;
    assert.strictEqual(
      editor.getValue(),
      "<header>Email header content</header>",
      "the email header content is loaded"
    );
    assert.strictEqual(
      editor.getSession().getMode().$id,
      "ace/mode/html",
      "the email header uses HTML mode"
    );

    await click(
      '.theme-editor__advanced-fields a[href="/admin/customize/themes/-1/email_footer/email_footer/edit"]'
    );

    assert.strictEqual(
      currentURL(),
      "/admin/customize/themes/-1/email_footer/email_footer/edit",
      "the footer link uses the footer target"
    );
    editor = find(".theme-editor__code").aceEditor;
    assert.strictEqual(
      editor.getValue(),
      "<footer>Email footer content</footer>",
      "the editor updates to the email footer content"
    );
    assert
      .dom(".theme-editor__code")
      .hasClass("ace_editor", "Ace styling remains active");
    assert
      .dom(".theme-editor__code .ace_text-layer")
      .includesText(
        "Email footer content",
        "Ace renders the email footer content"
      );
    assert.strictEqual(
      editor.getSession().getMode().$id,
      "ace/mode/html",
      "the email footer remains in HTML mode"
    );

    await click(
      '.theme-editor__fields a[href="/admin/customize/themes/-1/common/header/edit"]'
    );

    assert
      .dom(".d-toggle-switch__checkbox")
      .hasAttribute(
        "aria-checked",
        "true",
        "advanced mode remains enabled after navigating to a standard field"
      );
    assert
      .dom(".theme-editor__advanced-fields")
      .exists("the advanced email fields remain visible");
    assert.strictEqual(
      find(".theme-editor__code").aceEditor.getValue(),
      "",
      "the editor updates to the selected standard field"
    );
  });

  test("disables email fields when theme email fragments are disabled", async function (assert) {
    this.siteSettings.enable_email_theme_header_and_footer = false;

    await visit("/admin/customize/themes/-1/common/scss/edit");
    await click(".d-toggle-switch__checkbox");

    assert
      .dom(".theme-editor__advanced-fields")
      .hasClass("is-disabled", "the email field options appear disabled");
    assert
      .dom(".theme-editor__email-disabled-notice")
      .hasText(
        i18n("admin.customize.theme.email_theme_fields_disabled"),
        "the page explains that configured email fields will not be used"
      );
    assert
      .dom(".ace-wrapper")
      .hasAttribute(
        "data-disabled",
        "false",
        "non-email theme fields remain editable"
      );

    await click(
      '.theme-editor__advanced-fields a[href="/admin/customize/themes/-1/email_header/email_header/edit"]'
    );

    assert
      .dom(".ace-wrapper")
      .hasAttribute(
        "data-disabled",
        "true",
        "the email field editor is disabled"
      );
    assert
      .dom(".theme-editor__code")
      .hasAttribute(
        "aria-describedby",
        "theme-email-fields-disabled-notice",
        "the editor references the explanatory notice"
      )
      .hasAttribute("aria-readonly", "true", "the editor is marked read-only");
  });

  test("shows the compatibility-pinned ref for the pending update", async function (assert) {
    await visit("/admin/customize/themes/42");

    assert
      .dom(".status-message")
      .includesText(
        "Theme is 2 commits behind d-compat/2026.5",
        "the compat ref is interpolated into the commits-behind message"
      );
    assert
      .dom(".status-message code")
      .hasText("d-compat/2026.5", "the ref is rendered inside a code tag");
  });
});
