import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { click, currentRouteName, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Managing Group Email Settings - SMTP Disabled", function (needs) {
  needs.user();

  test("When SiteSetting.enable_smtp is false", async function (assert) {
    await visit("/g/alternative-group/manage/email");
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
      await visit("/g/alternative-group/manage/email");
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

    test("enabling SMTP, testing, and saving", async function (assert) {
      await visit("/g/alternative-group/manage/email");
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
    });
  }
);
