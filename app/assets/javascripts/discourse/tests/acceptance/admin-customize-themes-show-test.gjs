import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

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
                name: "en",
                target: "translations",
                value:
                  'en:\n  theme_metadata:\n    description: "The classic Discourse theme that is well-suited to customization for your community’s specific needs."\n',
                type_id: 5,
              },
            ],
            screenshot_url:
              "/uploads/default/original/1X/f8a61b9a0bfac672daec9e401787812f8c5e28df.png",
            system: true,
            color_scheme: null,
            owned_color_palette: null,
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
    withPluginApi("0.1", (api) => {
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
});
