import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Admin - email-preview", function (needs) {
  needs.user({ locale: "en" });
  needs.settings({
    available_locales: [
      { name: "English", value: "en" },
      { name: "Français", value: "fr" },
    ],
    default_locale: "en",
  });

  let previewEmailType;
  let previewHasContent;
  let previewLocale;
  let sentEmailType;
  let sentLocale;

  needs.hooks.beforeEach(function () {
    previewEmailType = null;
    previewHasContent = true;
    previewLocale = null;
    sentEmailType = null;
    sentLocale = null;
  });

  needs.pretender((server, helper) => {
    server.get("/admin/email/preview-digest.json", (request) => {
      previewEmailType = request.queryParams.email_type;
      previewLocale = request.queryParams.locale;
      if (!previewHasContent) {
        return helper.response(200, {
          subject: null,
          html_content: "",
          text_content: "",
        });
      }

      const templatePreview = previewEmailType?.startsWith("template:");

      return helper.response(200, {
        subject: templatePreview ? "Backup failed" : "Greetings",
        html_content: templatePreview
          ? "<span>Log: %{logs}</span>"
          : "<span>Hello world</span>",
        text_content: templatePreview
          ? "Log: %{logs}"
          : "<span>Not actually html</span>",
      });
    });

    server.get("/admin/email/preview-types.json", () => {
      return helper.response(200, {
        email_templates: [
          {
            id: "system_messages.backup_failed",
            title: "Backup failed",
          },
        ],
      });
    });

    server.post("/admin/email/send-digest.json", (request) => {
      const data = helper.parsePostData(request.requestBody);
      sentEmailType = data.email_type;
      sentLocale = data.locale;
      return helper.response({ success: "OK" });
    });
  });

  test("preview rendering", async function (assert) {
    await visit("/admin/email/preview-digest");

    assert
      .dom(".email-preview__subject")
      .hasText("Subject: Greetings", "shows the message subject");
    assert
      .dom(".preview-output iframe")
      .hasAttribute("sandbox", "", "isolates preview HTML from the admin page")
      .hasAttribute(
        "referrerpolicy",
        "no-referrer",
        "does not disclose the preview page URL to remote resources"
      )
      .hasAttribute(
        "srcdoc",
        "<span>Hello world</span>",
        "assigns the HTML preview to the iframe"
      );

    await click("a.show-text-link");
    assert
      .dom(".preview-output pre")
      .hasText(
        "<span>Not actually html</span>",
        "text content is escaped correctly"
      );
  });

  test("shows no result for an empty summary", async function (assert) {
    previewHasContent = false;

    await visit("/admin/email/preview-digest");

    assert
      .dom(".email-preview__subject")
      .doesNotExist("does not show an empty subject");
    assert
      .dom(".email-preview-digest .controls")
      .doesNotExist("does not offer to send an empty summary");
    assert
      .dom(".preview-output iframe")
      .doesNotExist("does not render an empty email document");
    assert
      .dom(".preview-output")
      .hasText(
        i18n("admin.email.no_result"),
        "explains that the summary has no result"
      );
  });

  test("previews password reset message types", async function (assert) {
    await visit("/admin/email/preview-digest");

    assert.strictEqual(
      previewEmailType,
      "digest",
      "previews a summary initially"
    );
    assert.dom("#last-seen").exists("shows summary-specific controls");

    await selectKit(".email-preview__type-selector").expand();
    await selectKit(".email-preview__type-selector").selectRowByValue(
      "password_reset"
    );

    assert.dom("#last-seen").doesNotExist("hides summary-specific controls");

    await click(".digest-refresh-button");
    assert.strictEqual(
      previewEmailType,
      "password_reset",
      "previews a password reset link"
    );

    await selectKit(".email-preview__type-selector").expand();
    await selectKit(".email-preview__type-selector").selectRowByValue(
      "password_reset_code"
    );
    await click(".digest-refresh-button");

    assert.strictEqual(
      previewEmailType,
      "password_reset_code",
      "previews a password reset code"
    );

    await selectKit(".email-preview__type-selector").expand();
    await selectKit(".email-preview__type-selector").selectRowByValue(
      "email_login_code"
    );
    await click(".digest-refresh-button");

    assert.strictEqual(
      previewEmailType,
      "email_login_code",
      "previews an email login code"
    );
  });

  test("previews literal email templates", async function (assert) {
    await visit("/admin/email/preview-digest");

    const typeSelector = selectKit(".email-preview__type-selector");
    await typeSelector.expand();
    assert
      .dom(
        typeSelector.rowByValue("template:system_messages.backup_failed").el()
      )
      .hasText(
        "Template: Backup failed",
        "does not append the template identifier"
      );
    await typeSelector.selectRowByValue(
      "template:system_messages.backup_failed"
    );

    assert
      .dom("#last-seen")
      .doesNotExist("hides summary-specific controls for templates");
    assert
      .dom(".email-preview__template-notice")
      .exists("explains the limitations of literal template previews");

    await click(".digest-refresh-button");

    assert.strictEqual(
      previewEmailType,
      "template:system_messages.backup_failed",
      "requests the selected template"
    );
    assert
      .dom(".email-preview__subject")
      .hasText("Subject: Backup failed", "shows the template subject");

    await click("a.show-text-link");
    assert
      .dom(".preview-output pre")
      .includesText("%{logs}", "leaves substitutions unresolved");

    await fillIn(
      ".email-preview-digest .controls input[type='text']",
      "preview@example.com"
    );
    await click(".email-preview-digest .controls .btn-default");

    assert.strictEqual(
      sentEmailType,
      "template:system_messages.backup_failed",
      "sends the literal template preview"
    );
  });

  test("uses the selected locale for previews and test emails", async function (assert) {
    await visit("/admin/email/preview-digest");

    assert.strictEqual(previewLocale, "en", "previews the initial locale");
    assert.strictEqual(
      selectKit(".email-preview__locale-selector").header().value(),
      "en",
      "shows the initial locale"
    );

    await selectKit(".email-preview__locale-selector").expand();
    await selectKit(".email-preview__locale-selector").selectRowByValue("fr");
    await click(".digest-refresh-button");

    assert.strictEqual(previewLocale, "fr", "previews the selected locale");

    await fillIn(
      ".email-preview-digest .controls input[type='text']",
      "preview@example.com"
    );
    await click(".email-preview-digest .controls .btn-default");

    assert.strictEqual(
      sentEmailType,
      "digest",
      "sends the selected message type"
    );
    assert.strictEqual(sentLocale, "fr", "sends the selected locale");
  });

  test("send preview form requires a destination email", async function (assert) {
    await visit("/admin/email/preview-digest");

    assert
      .dom(".email-preview-digest .controls")
      .exists("send email form is shown");

    assert
      .dom(".email-preview-digest .controls input[type='text']")
      .exists("an email text field is shown for sending this preview");

    assert
      .dom(".email-preview-digest .controls .btn-default")
      .isDisabled("send button is disabled until an email address is entered");

    await fillIn(
      ".email-preview-digest .controls input[type='text']",
      "preview@example.com"
    );

    assert
      .dom(".email-preview-digest .controls .btn-default")
      .isNotDisabled("send button is enabled once an email address is entered");
  });
});
