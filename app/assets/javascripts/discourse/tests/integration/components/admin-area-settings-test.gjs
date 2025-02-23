import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import AdminAreaSettings from "admin/components/admin-area-settings";

module("Integration | Component | AdminAreaSettings", function (hooks) {
  hooks.beforeEach(function () {
    pretender.get("/admin/config/site_settings.json", () =>
      response({
        site_settings: [
          {
            setting: "silence_new_user_sensitivity",
            description:
              "The likelihood that a new user will be silenced based on spam flags",
            keywords: [],
            default: "3",
            value: "3",
            category: "spam",
            preview: null,
            secret: false,
            placeholder: null,
            mandatory_values: null,
            requires_confirmation: null,
            type: "enum",
            valid_values: [
              {
                name: "Disabled",
                value: 0,
              },
              {
                name: "Low",
                value: 9,
              },
              {
                name: "Medium",
                value: 6,
              },
              {
                name: "High",
                value: 3,
              },
            ],
            translate_names: false,
          },
          {
            setting: "num_users_to_silence_new_user",
            description:
              "If a new user's posts exceed the hide_post_sensitivity setting, and has spam flags from this many different users, hide all their posts and prevent future posting. 0 to disable.",
            keywords: [],
            default: "3",
            value: "4",
            category: "spam",
            preview: null,
            secret: false,
            placeholder: null,
            mandatory_values: null,
            requires_confirmation: null,
            type: "integer",
          },
        ],
      })
    );
  });
  setupRenderingTest(hooks);

  test("renders area settings and allows to filter", async function (assert) {
    const callback = () => {};
    await render(<template>
      <AdminAreaSettings
        @area="flags"
        @adminSettingsFilterChangedCallback={{callback}}
        @filter=""
      />
    </template>);

    assert.dom(".admin-site-settings-filter-controls").exists();
    assert.dom(".setting-label").exists({ count: 2 });

    await fillIn("#setting-filter", "num");
    assert.dom(".setting-label").exists({ count: 1 });
  });
});
