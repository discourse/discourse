import { click, currentRouteName, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { GROUP_SMTP_SSL_MODES } from "discourse/lib/constants";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Managing Group Email Settings - SMTP Disabled", function (needs) {
  needs.user();

  test("When SiteSetting.enable_smtp is false", async function (assert) {
    await visit("/g/discourse/manage/email");
    assert
      .dom(".user-secondary-navigation")
      .doesNotIncludeText("Email", "email link is not shown in the sidebar");
    assert.strictEqual(
      currentRouteName(),
      "group.manage.profile",
      "it redirects to the group profile page"
    );
  });
});

acceptance("Managing Group Email Settings - SMTP Enabled", function (needs) {
  needs.user();
  needs.settings({ enable_smtp: true });

  needs.pretender((server, helper) => {
    server.post("/groups/47/test_email_settings", () => {
      return helper.response({
        success: "OK",
      });
    });
    server.put("/groups/47", () => {
      return helper.response({
        success: "OK",
      });
    });
    server.put("/admin/groups/automatic_membership_count.json", () => {
      return helper.response({
        user_count: 0,
      });
    });
  });

  test("When SiteSetting.enable_smtp is true", async function (assert) {
    await visit("/g/discourse/manage/email");
    assert
      .dom(".user-secondary-navigation")
      .includesText("Email", "email link is shown in the sidebar");
    assert.strictEqual(
      currentRouteName(),
      "group.manage.email",
      "it redirects to the group email page"
    );
  });

  test("enabling SMTP, testing, and saving", async function (assert) {
    await visit("/g/discourse/manage/email");
    assert
      .dom(".user-secondary-navigation")
      .includesText("Email", "email link is shown in the sidebar");

    await click("#enable_smtp");
    assert.dom(".group-smtp-email-settings").exists();

    await click("#prefill_smtp_gmail");
    assert
      .form()
      .field("smtp_server")
      .hasValue("smtp.gmail.com", "prefills SMTP server settings for gmail");
    assert
      .form()
      .field("smtp_port")
      .hasValue("587", "prefills SMTP port settings for gmail");
    assert
      .form()
      .field("smtp_ssl_mode")
      .hasValue(
        GROUP_SMTP_SSL_MODES.starttls.toString(),
        "prefills SSL mode to STARTTLS for gmail"
      );

    await formKit().submit();
    assert.form().hasErrors(
      {
        [i18n("groups.manage.email.credentials.username")]: "Required",
        [i18n("groups.manage.email.credentials.password")]: "Required",
      },
      "does not allow testing settings if not all fields are filled"
    );

    await formKit().field("email_username").fillIn("myusername@gmail.com");
    await formKit().field("email_password").fillIn("password");
    await formKit()
      .field("email_from_alias")
      .fillIn("akasomegroup@example.com");

    await formKit().submit();
    await click(".group-manage-save");

    assert.dom(".group-manage-save-button > span").hasText("Saved!");

    await click("#enable_smtp");
    assert
      .dom(".dialog-body")
      .hasText(
        i18n("groups.manage.email.smtp_disable_confirm"),
        "shows a confirm dialogue warning SMTP settings will be wiped"
      );

    await click(".dialog-footer .btn-primary");
  });
});

acceptance(
  "Managing Group Email Settings - SMTP Enabled - Settings Prefilled",
  function (needs) {
    needs.user();
    needs.settings({ enable_smtp: true });

    needs.pretender((server, helper) => {
      server.get("/groups/discourse.json", () => {
        return helper.response(200, {
          group: {
            id: 47,
            automatic: false,
            name: "discourse",
            full_name: "Awesome Team",
            user_count: 8,
            alias_level: 99,
            visible: true,
            public_admission: true,
            public_exit: false,
            flair_url: "circle-half-stroke",
            is_group_owner: true,
            mentionable: true,
            messageable: true,
            can_see_members: true,
            has_messages: true,
            message_count: 2,
            smtp_server: "smtp.gmail.com",
            smtp_port: 587,
            smtp_ssl_mode: GROUP_SMTP_SSL_MODES.starttls,
            smtp_enabled: true,
            smtp_updated_at: "2021-06-16T02:58:12.739Z",
            smtp_updated_by: {
              id: 19,
              username: "eviltrout",
              name: "Robin Ward",
              avatar_template:
                "/letter_avatar/eviltrout/{size}/3_f9720745f5ce6dfc2b5641fca999d934.png",
            },
            email_username: "test@test.com",
            email_password: "password",
          },
          extras: {
            visible_group_names: ["discourse"],
          },
        });
      });
    });

    test("prefills smtp saved settings and shows last updated details", async function (assert) {
      await visit("/g/discourse/manage/email");

      assert.dom("#enable_smtp").isNotDisabled("SMTP is not disabled");

      assert
        .form()
        .field("email_username")
        .hasValue("test@test.com", "email username is prefilled");
      assert
        .form()
        .field("email_password")
        .hasValue("password", "email password is prefilled");
      assert
        .form()
        .field("smtp_server")
        .hasValue("smtp.gmail.com", "SMTP server is prefilled");
      assert
        .form()
        .field("smtp_port")
        .hasValue("587", "SMTP port is prefilled");
      assert
        .form()
        .field("smtp_ssl_mode")
        .hasValue(
          GROUP_SMTP_SSL_MODES.starttls.toString(),
          "SMTP ssl mode is prefilled"
        );
    });
  }
);

acceptance(
  "Managing Group Email Settings - SMTP Enabled - Email Test Invalid",
  function (needs) {
    needs.user();
    needs.settings({ enable_smtp: true });

    needs.pretender((server, helper) => {
      server.post("/groups/47/test_email_settings", () => {
        return helper.response(422, {
          success: false,
          errors: [
            "There was an issue with the SMTP credentials provided, check the username and password and try again.",
          ],
        });
      });
    });

    test("shows error when SMTP test fails", async function (assert) {
      await visit("/g/discourse/manage/email");

      await click("#enable_smtp");
      await click("#prefill_smtp_gmail");
      await formKit().field("email_username").fillIn("myusername@gmail.com");
      await formKit().field("email_password").fillIn("password");
      await formKit().submit();

      assert.dom(".dialog-body").hasText(
        i18n("generic_error_with_reason", {
          error:
            "There was an issue with the SMTP credentials provided, check the username and password and try again.",
        })
      );
      await click(".dialog-footer .btn-primary");
    });
  }
);
