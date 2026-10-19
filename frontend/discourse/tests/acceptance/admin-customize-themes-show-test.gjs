import { click, currentURL, find, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - Customize - Themes - Show", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/admin/themes", () => {
      const localTheme = {
        id: 43,
        name: "Local custom theme",
        default: false,
        component: false,
        user_selectable: false,
        enabled: true,
        supported: true,
        settings: [],
        theme_fields: [
          {
            name: "header",
            target: "email",
            value: "<header>Email header content</header>",
            type_id: 0,
          },
          {
            name: "footer",
            target: "email",
            value: "<footer>Email footer content</footer>",
            type_id: 0,
          },
        ],
        child_themes: [],
        parent_themes: [],
        remote_theme: null,
      };
      return helper.response({
        themes: [
          localTheme,
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
                name: "header",
                target: "email",
                value: "<header>Email header content</header>",
                type_id: 0,
              },
              {
                name: "footer",
                target: "email",
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

  test("hides the email tab when branding is disabled and on built-in themes", async function (assert) {
    await visit("/admin/customize/themes/43/common/scss/edit");
    await click(".d-toggle-switch__checkbox");
    assert
      .dom('.edit-main-nav a[href*="/email/"]')
      .doesNotExist("disabled branding has no email tab");

    this.siteSettings.enable_email_theme_header_and_footer = true;
    await visit("/admin/customize/themes/-1/common/scss/edit");
    assert
      .dom('.edit-main-nav a[href*="/email/"]')
      .doesNotExist("built-in themes have no editable email tab");
  });

  test("preserves email rendering and advanced state across field navigation", async function (assert) {
    this.siteSettings.enable_email_theme_header_and_footer = true;
    await visit("/admin/customize/themes/43/email/header/edit");

    let editor = find(".theme-editor__code").aceEditor;
    assert.strictEqual(
      editor.getValue(),
      "<header>Email header content</header>",
      "loads the header"
    );
    await click(
      '.theme-editor__fields a[href="/admin/customize/themes/43/email/footer/edit"]'
    );
    editor = find(".theme-editor__code").aceEditor;
    assert.strictEqual(
      editor.getValue(),
      "<footer>Email footer content</footer>",
      "loads the footer"
    );
    assert.strictEqual(
      editor.session.getMode().$id,
      "ace/mode/html",
      "keeps HTML mode"
    );
    assert
      .dom(".theme-editor__code")
      .hasClass("ace_editor", "keeps Ace styling");
    assert
      .dom(".theme-editor__code .ace_text-layer")
      .includesText("Email footer content", "renders the footer");

    await click(
      '.theme-editor__fields a[href="/admin/customize/themes/43/email/footer_text/edit"]'
    );
    assert.strictEqual(
      find(".theme-editor__code").aceEditor.session.getMode().$id,
      "ace/mode/text",
      "plain-text overrides use text mode"
    );
    await click(
      '.edit-main-nav a[href="/admin/customize/themes/43/common/scss/edit"]'
    );
    assert
      .dom(".d-toggle-switch__checkbox")
      .hasAttribute("aria-checked", "true", "advanced mode persists");
    assert
      .dom(
        '.edit-main-nav a[href="/admin/customize/themes/43/email/header/edit"]'
      )
      .exists("the email tab remains visible");
  });

  test("redirects disabled email editors back to the theme page", async function (assert) {
    await visit("/admin/customize/themes/43/email/header/edit");
    assert.strictEqual(
      currentURL(),
      "/admin/customize/themes/43",
      "disabled email editors are not exposed"
    );
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
