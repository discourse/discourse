import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Theme", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    const themes = [
      {
        id: 42,
        name: "discourse-incomplete-theme",
        created_at: "2022-01-01T12:00:00.000Z",
        updated_at: "2022-01-01T12:00:00.000Z",
        component: false,
        color_scheme: null,
        user_selectable: false,
        remote_theme_id: 42,
        supported: true,
        description: null,
        enabled: true,
        child_themes: [],
        remote_theme: {
          id: 42,
          remote_url: "git@github.com:discourse/discourse-incomplete-theme.git",
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
      },
    ];

    server.get("/admin/themes", () => {
      return helper.response(200, { themes });
    });

    server.get("/admin/config/customize/themes", () => {
      return helper.response(200, { themes });
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
    await visit("/admin/config/customize/themes");

    await click(".d-page-subheader__actions .btn-primary");
    await click(".install-theme-items #remote");
    await fillIn(
      ".install-theme-content .repo input",
      "git@github.com:discourse/discourse-inexistent-theme.git"
    );
    await click(".install-theme-content button.advanced-repo");

    assert
      .dom(".admin-install-theme-modal .d-modal__footer .install-theme-warning")
      .doesNotExist("no Git warning is displayed");

    await click(".admin-install-theme-modal .d-modal__footer .btn-primary");
    assert
      .dom(".admin-install-theme-modal .d-modal__footer .install-theme-warning")
      .exists("Git warning is displayed");

    await click(".admin-install-theme-modal .d-modal__footer .btn-danger");

    assert.dom(".admin-install-theme-modal").doesNotExist("modal is closed");
  });

  test("can continue installation", async function (assert) {
    await visit("/admin/config/customize/themes");

    await click(".theme-card .btn-secondary");
    assert
      .dom(".control-unit .status-message")
      .includesText(
        i18n("admin.customize.theme.last_attempt"),
        "says that theme is not completely installed"
      );

    await click(".control-unit .btn-primary.finish-install");

    assert
      .dom(".show-current-style .title span")
      .hasText("discourse-complete-theme", "updates theme title");

    assert
      .dom(".metadata.control-unit")
      .doesNotIncludeText(
        i18n("admin.customize.theme.last_attempt"),
        "does not say that theme is not completely installed"
      );

    assert
      .dom(".control-unit .btn-primary.finish-install")
      .doesNotExist("does not show finish install button");
  });
});
