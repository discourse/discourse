import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { click, currentRouteName, fillIn, visit } from "@ember/test-helpers";
import I18n from "I18n";
import { test } from "qunit";

acceptance("Managing Group Email Settings - SMTP Disabled", function (needs) {
  needs.user();

  test("When SiteSetting.enable_smtp is false", async function (assert) {
    await visit("/g/discourse/manage/email");
    assert.equal(
      currentRouteName(),
      "group.manage.profile",
      "it redirects to the group profile page"
    );
  });
});

acceptance(
  "Managing Group Email Settings - SMTP Enabled, IMAP Disabled",
  function (needs) {
    needs.user();
    needs.settings({ enable_smtp: true });

    test("When SiteSetting.enable_smtp is true but SiteSetting.enable_imap is false", async function (assert) {
      await visit("/g/discourse/manage/email");
      assert.equal(
        currentRouteName(),
        "group.manage.email",
        "it redirects to the group email page"
      );
      assert.notOk(
        exists(".group-manage-email-imap-wrapper"),
        "does not show IMAP settings"
      );
    });
  }
);

acceptance(
  "Managing Group Email Settings - SMTP and IMAP Enabled",
  function (needs) {
    needs.user();
    needs.settings({ enable_smtp: true, enable_imap: true });

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
    });

    test("enabling SMTP, testing, and saving", async function (assert) {
      await visit("/g/discourse/manage/email");
      assert.ok(
        exists("#enable_imap:disabled"),
        "IMAP is disabled until SMTP settings are valid"
      );

      await click("#enable_smtp");
      assert.ok(exists(".group-smtp-email-settings"));

      await click("#prefill_smtp_gmail");
      assert.equal(
        queryAll("input[name='smtp_server']").val(),
        "smtp.gmail.com",
        "prefills SMTP server settings for gmail"
      );
      assert.equal(
        queryAll("input[name='smtp_port']").val(),
        "587",
        "prefills SMTP port settings for gmail"
      );
      assert.ok(
        exists("#enable_ssl:checked"),
        "prefills SMTP ssl settings for gmail"
      );

      assert.ok(
        exists(".test-smtp-settings:disabled"),
        "does not allow testing settings if not all fields are filled"
      );

      await fillIn('input[name="username"]', "myusername@gmail.com");
      await fillIn('input[name="password"]', "password@gmail.com");
      await click(".test-smtp-settings");

      assert.ok(exists(".smtp-settings-ok"), "tested settings are ok");

      await click(".group-manage-save");

      assert.equal(
        queryAll(".group-manage-save-button > span").text(),
        "Saved!"
      );

      assert.notOk(
        exists("#enable_imap:disabled"),
        "IMAP is able to be enabled now that SMTP is saved"
      );

      await click("#enable_smtp");
      assert.equal(
        queryAll(".modal-body").text(),
        I18n.t("groups.manage.email.smtp_disable_confirm"),
        "shows a confirm dialogue warning SMTP settings will be wiped"
      );

      await click(".modal-footer .btn.btn-primary");
    });

    test("enabling IMAP, testing, and saving", async function (assert) {
      await visit("/g/discourse/manage/email");

      await click("#enable_smtp");
      await click("#prefill_smtp_gmail");
      await fillIn('input[name="username"]', "myusername@gmail.com");
      await fillIn('input[name="password"]', "password@gmail.com");
      await click(".test-smtp-settings");
      await click(".group-manage-save");

      assert.notOk(
        exists("#enable_imap:disabled"),
        "IMAP is able to be enabled now that IMAP is saved"
      );

      await click("#enable_imap");

      assert.ok(
        exists(".test-imap-settings:disabled"),
        "does not allow testing settings if not all fields are filled"
      );

      await click("#prefill_imap_gmail");
      assert.equal(
        queryAll("input[name='imap_server']").val(),
        "imap.gmail.com",
        "prefills IMAP server settings for gmail"
      );
      assert.equal(
        queryAll("input[name='imap_port']").val(),
        "993",
        "prefills IMAP port settings for gmail"
      );
      assert.ok(
        exists("#enable_ssl:checked"),
        "prefills IMAP ssl settings for gmail"
      );
      await click(".test-imap-settings");

      assert.ok(exists(".imap-settings-ok"), "tested settings are ok");

      await click(".group-manage-save");

      assert.equal(
        queryAll(".group-manage-save-button > span").text(),
        "Saved!"
      );

      assert.ok(
        exists(".imap-no-mailbox-selected"),
        "shows a message saying no IMAP mailbox is selected"
      );

      await selectKit(
        ".control-group.group-imap-mailboxes .combo-box"
      ).expand();
      await selectKit(
        ".control-group.group-imap-mailboxes .combo-box"
      ).selectRowByValue("All Mail");
      await click(".group-manage-save");

      assert.notOk(
        exists(".imap-no-mailbox-selected"),
        "no longer shows a no mailbox selected message"
      );

      await click("#enable_imap");
      assert.equal(
        queryAll(".modal-body").text(),
        I18n.t("groups.manage.email.imap_disable_confirm"),
        "shows a confirm dialogue warning IMAP settings will be wiped"
      );
      await click(".modal-footer .btn.btn-primary");
    });
  }
);

acceptance(
  "Managing Group Email Settings - SMTP and IMAP Enabled - Email Test Invalid",
  function (needs) {
    needs.user();
    needs.settings({ enable_smtp: true, enable_imap: true });

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

    test("enabling IMAP, testing, and saving", async function (assert) {
      await visit("/g/discourse/manage/email");

      await click("#enable_smtp");
      await click("#prefill_smtp_gmail");
      await fillIn('input[name="username"]', "myusername@gmail.com");
      await fillIn('input[name="password"]', "password@gmail.com");
      await click(".test-smtp-settings");

      assert.equal(
        queryAll(".modal-body").text(),
        "There was an issue with the SMTP credentials provided, check the username and password and try again.",
        "shows a dialogue with the error message from the server"
      );
      await click(".modal-footer .btn.btn-primary");
    });
  }
);
