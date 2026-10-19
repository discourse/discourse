import { click, currentURL, fillIn, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import EmailPreview from "discourse/admin/models/email-preview";
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
  let previewFails;
  let previewThemeId;
  let sentThemeId;
  let previewLocale;
  let sentEmailType;
  let sentLocale;

  needs.hooks.beforeEach(function () {
    previewEmailType = null;
    previewHasContent = true;
    previewFails = false;
    previewThemeId = null;
    sentThemeId = null;
    previewLocale = null;
    sentEmailType = null;
    sentLocale = null;
  });

  needs.pretender((server, helper) => {
    server.get("/admin/email/preview.json", (request) => {
      previewEmailType = request.queryParams.email_type;
      previewLocale = request.queryParams.locale;
      previewThemeId = request.queryParams.theme_id;
      if (previewFails) {
        return helper.response(422, { errors: ["Preview failed"] });
      }
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
        message_types: [
          "digest",
          "password_reset",
          "password_reset_code",
          "email_login_code",
          "test_email",
        ].map((id) => ({ id, title: i18n(`admin.email.preview_types.${id}`) })),
        branding_themes: [{ id: 43, title: "Draft theme" }],
        email_templates: [
          {
            id: "system_messages.backup_failed",
            title: "Backup failed",
          },
        ],
      });
    });

    server.post("/admin/email/send-preview.json", (request) => {
      const data = helper.parsePostData(request.requestBody);
      sentEmailType = data.email_type;
      sentLocale = data.locale;
      sentThemeId = data.theme_id;
      return helper.response({ success: "OK" });
    });
  });

  test("redirects legacy preview links with their selections", async function (assert) {
    await visit(
      "/admin/email/preview-digest?email_type=password_reset&locale=fr&theme_id=43"
    );

    assert.strictEqual(
      currentURL().split("?")[0],
      "/admin/email/preview",
      "uses the canonical preview URL"
    );
    assert.strictEqual(
      previewEmailType,
      "password_reset",
      "preserves the message type"
    );
    assert.strictEqual(previewLocale, "fr", "preserves the language");
    assert.strictEqual(previewThemeId, "43", "preserves the branding theme");
  });

  test("preview rendering", async function (assert) {
    await visit("/admin/email/preview");

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

    await visit("/admin/email/preview");

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
    await visit("/admin/email/preview");

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
    await visit("/admin/email/preview");

    const typeSelector = selectKit(".email-preview__type-selector");
    await typeSelector.expand();
    assert
      .dom(
        typeSelector.rowByValue("template:system_messages.backup_failed").el()
      )
      .doesNotExist(
        "literal templates do not crowd the general message selector"
      );
    await visit(
      "/admin/email/preview?email_type=template%3Asystem_messages.backup_failed"
    );
    assert
      .dom(".email-preview__type-selector")
      .includesText(
        "Template: Backup failed",
        "names the template opened from its editor"
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
    await visit("/admin/email/preview");

    assert.strictEqual(
      previewLocale,
      "",
      "lets the server use the selected user’s locale"
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

  test("requires a refreshed preview after changing type or locale", async function (assert) {
    await visit("/admin/email/preview");
    await fillIn(
      ".email-preview-digest .controls input[type='text']",
      "preview@example.com"
    );
    await selectKit(".email-preview__type-selector").expand();
    await selectKit(".email-preview__type-selector").selectRowByValue(
      "password_reset"
    );
    assert
      .dom(".email-preview-digest .controls .btn-default")
      .isDisabled("a changed selection cannot send the old preview");
    assert
      .dom(".email-preview__stale")
      .exists("explains that the preview is stale");
    await click(".digest-refresh-button");
    assert
      .dom(".email-preview-digest .controls .btn-default")
      .isEnabled("a successful refresh enables sending");
    await click(".email-preview-digest .controls .btn-default");
    assert.strictEqual(
      sentEmailType,
      "password_reset",
      "sends the newly rendered type"
    );
  });

  test("loads preview selections from the URL", async function (assert) {
    await visit(
      "/admin/email/preview?email_type=password_reset&locale=fr&theme_id=43"
    );
    assert.strictEqual(
      previewEmailType,
      "password_reset",
      "uses the linked message type"
    );
    assert.strictEqual(previewLocale, "fr", "uses the linked language");
    assert.dom("#last-seen").doesNotExist("uses non-summary controls");
  });

  test("keeps the newest preview when refresh responses arrive out of order", async function (assert) {
    await visit("/admin/email/preview");
    const controller = this.owner.lookup(
      "controller:admin-email.preview-digest"
    );
    let resolveFirst;
    let resolveSecond;
    const requestStub = sinon.stub(EmailPreview, "findPreview");
    requestStub.onFirstCall().returns(
      new Promise((resolve) => {
        resolveFirst = resolve;
      })
    );
    requestStub.onSecondCall().returns(
      new Promise((resolve) => {
        resolveSecond = resolve;
      })
    );
    try {
      const first = controller.refresh();
      controller.updateLocale("fr");
      const second = controller.refresh();
      resolveSecond(
        EmailPreview.create({
          subject: "Newest preview",
          html_content: "<p>Newest</p>",
          text_content: "Newest",
        })
      );
      await second;
      resolveFirst(
        EmailPreview.create({
          subject: "Older preview",
          html_content: "<p>Older</p>",
          text_content: "Older",
        })
      );
      await first;
      await settled();
      assert
        .dom(".email-preview__subject")
        .includesText(
          "Newest preview",
          "an older response cannot replace the newest result"
        );
      assert
        .dom(".email-preview__stale")
        .doesNotExist("the newest response matches the current selections");
    } finally {
      requestStub.restore();
    }
  });

  test("recovers from a failed refresh without enabling stale sends", async function (assert) {
    await visit("/admin/email/preview");
    previewFails = true;
    await click(".digest-refresh-button");
    assert
      .dom(".dialog-body")
      .includesText("Preview failed", "shows the request error");
    await click(".dialog-footer .btn-primary");
    assert
      .dom(".email-preview-digest")
      .exists("clears the loading state after failure");
    await fillIn(
      ".email-preview-digest .controls input[type='text']",
      "preview@example.com"
    );
    assert
      .dom(".email-preview-digest .controls .btn-default")
      .isDisabled("failed refreshes cannot send old content");
    previewFails = false;
    await click(".digest-refresh-button");
    assert
      .dom(".email-preview-digest .controls .btn-default")
      .isEnabled("a successful retry restores sending");
  });

  test("previews and sends branding from the selected draft theme", async function (assert) {
    await visit("/admin/email/preview");
    await selectKit(".email-preview__theme-selector").expand();
    await selectKit(".email-preview__theme-selector").selectRowByValue(43);
    await click(".digest-refresh-button");
    assert.strictEqual(
      previewThemeId,
      "43",
      "passes the draft theme to the preview"
    );
    await fillIn(
      ".email-preview-digest .controls input[type='text']",
      "preview@example.com"
    );
    await click(".email-preview-digest .controls .btn-default");
    assert.strictEqual(sentThemeId, "43", "sends the same draft branding");
  });

  test("send preview form requires a destination email", async function (assert) {
    await visit("/admin/email/preview");

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
