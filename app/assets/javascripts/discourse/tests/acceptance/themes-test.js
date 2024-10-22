import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

acceptance("Theme", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/admin/themes", () => {
      return helper.response(200, {
        themes: [
          {
            id: 42,
            name: "discourse-incomplete-theme",
            created_at: "2022-01-01T12:00:00.000Z",
            updated_at: "2022-01-01T12:00:00.000Z",
            component: false,
            color_scheme: null,
            color_scheme_id: null,
            user_selectable: false,
            auto_update: true,
            remote_theme_id: 42,
            settings: [],
            supported: true,
            description: null,
            enabled: true,
            user: {
              id: 1,
              username: "foo",
              name: null,
              avatar_template:
                "/letter_avatar_proxy/v4/letter/f/3be4f8/{size}.png",
              title: "Tester",
            },
            theme_fields: [],
            child_themes: [],
            parent_themes: [],
            remote_theme: {
              id: 42,
              remote_url:
                "git@github.com:discourse/discourse-incomplete-theme.git",
              remote_version: null,
              local_version: null,
              commits_behind: null,
              branch: null,
              remote_updated_at: null,
              updated_at: "2022-01-01T12:00:00.000Z",
              last_error_text: null,
              is_git: true,
              license_url: null,
              about_url: null,
              authors: null,
              theme_version: null,
              minimum_discourse_version: null,
              maximum_discourse_version: null,
            },
            translations: [],
          },
        ],
      });
    });

    server.post("/admin/themes/import", (request) => {
      const data = helper.parsePostData(request.requestBody);

      if (!data.force) {
        return helper.response(422, {
          errors: [
            "Error cloning git repository, access is denied or repository is not found",
          ],
        });
      }

      return helper.response(201, {
        theme: {
          id: 42,
          name: "discourse-inexistent-theme",
          created_at: "2022-01-01T12:00:00.000Z",
          updated_at: "2022-01-01T12:00:00.000Z",
          component: false,
          color_scheme: null,
          color_scheme_id: null,
          user_selectable: false,
          auto_update: true,
          remote_theme_id: 42,
          settings: [],
          supported: true,
          description: null,
          enabled: true,
          user: {
            id: 1,
            username: "foo",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/f/3be4f8/{size}.png",
          },
          theme_fields: [],
          child_themes: [],
          parent_themes: [],
          remote_theme: {
            id: 42,
            remote_url:
              "git@github.com:discourse/discourse-inexistent-theme.git",
            remote_version: null,
            local_version: null,
            commits_behind: null,
            branch: null,
            remote_updated_at: null,
            updated_at: "2022-01-01T12:00:00.000Z",
            last_error_text: null,
            is_git: true,
            license_url: null,
            about_url: null,
            authors: null,
            theme_version: null,
            minimum_discourse_version: null,
            maximum_discourse_version: null,
          },
          translations: [],
        },
      });
    });

    server.put("/admin/themes/42", () => {
      return helper.response(200, {
        theme: {
          id: 42,
          name: "discourse-complete-theme",
          created_at: "2022-01-01T12:00:00.000Z",
          updated_at: "2022-01-01T12:00:00.000Z",
          component: false,
          color_scheme: null,
          color_scheme_id: null,
          user_selectable: false,
          auto_update: true,
          remote_theme_id: 42,
          settings: [],
          supported: true,
          description: null,
          enabled: true,
          user: {
            id: 1,
            username: "foo",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/f/3be4f8/{size}.png",
          },
          theme_fields: [],
          child_themes: [],
          parent_themes: [],
          remote_theme: {
            id: 42,
            remote_url:
              "git@github.com:discourse-org/discourse-incomplete-theme.git",
            remote_version: "0000000000000000000000000000000000000000",
            local_version: "0000000000000000000000000000000000000000",
            commits_behind: 0,
            branch: null,
            remote_updated_at: "2022-01-01T12:00:30.000Z",
            updated_at: "2022-01-01T12:00:30.000Z",
            last_error_text: null,
            is_git: true,
            license_url: "URL",
            about_url: "URL",
            authors: null,
            theme_version: null,
            minimum_discourse_version: null,
            maximum_discourse_version: null,
          },
          translations: [],
        },
      });
    });
  });

  test("can force install themes", async function (assert) {
    await visit("/admin/customize/themes");

    await click(".themes-list .create-actions button");
    await click(".install-theme-items #remote");
    await fillIn(
      ".install-theme-content .repo input",
      "git@github.com:discourse/discourse-inexistent-theme.git"
    );
    await click(".install-theme-content button.advanced-repo");

    assert.notOk(
      exists(
        ".admin-install-theme-modal .d-modal__footer .install-theme-warning"
      ),
      "no Git warning is displayed"
    );

    await click(".admin-install-theme-modal .d-modal__footer .btn-primary");
    assert.ok(
      exists(
        ".admin-install-theme-modal .d-modal__footer .install-theme-warning"
      ),
      "Git warning is displayed"
    );

    await click(".admin-install-theme-modal .d-modal__footer .btn-danger");

    assert
      .dom(".admin-install-theme-modal:visible")
      .doesNotExist("modal is closed");
  });

  test("can continue installation", async function (assert) {
    await visit("/admin/customize/themes");

    await click(".themes-list-container__item .info");
    assert.ok(
      query(".control-unit .status-message").innerText.includes(
        I18n.t("admin.customize.theme.last_attempt")
      ),
      "it says that theme is not completely installed"
    );

    await click(".control-unit .btn-primary.finish-install");

    assert.equal(
      query(".show-current-style .title span").innerText,
      "discourse-complete-theme",
      "it updates theme title"
    );

    assert.notOk(
      query(".metadata.control-unit").innerText.includes(
        I18n.t("admin.customize.theme.last_attempt")
      ),
      "it does not say that theme is not completely installed"
    );

    assert.notOk(
      query(".control-unit .btn-primary.finish-install"),
      "it does not show finish install button"
    );
  });
});
