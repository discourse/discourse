import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Admin - email-preview", function (needs) {
  let previewHasContent;

  needs.hooks.beforeEach(() => {
    previewHasContent = true;
  });

  needs.user();
  needs.pretender((server, helper) => {
    server.get("/admin/email/preview-digest.json", () =>
      helper.response(200, {
        html_content: previewHasContent ? "<span>Hello world</span>" : "",
        text_content: previewHasContent ? "<span>Not actually html</span>" : "",
      })
    );
  });

  test("preview rendering", async function (assert) {
    await visit("/admin/email/preview-digest");
    assert
      .dom(".preview-output iframe")
      .hasAttribute(
        "srcdoc",
        "<span>Hello world</span>",
        "the preview HTML is supplied to the iframe"
      )
      .hasAttribute("sandbox", "", "the preview has no sandbox permissions")
      .hasAttribute(
        "referrerpolicy",
        "no-referrer",
        "the preview does not send referrers"
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
      .dom(".preview-output iframe")
      .doesNotExist("an empty summary has no preview document");
    assert
      .dom(".preview-output")
      .hasText(
        i18n("admin.email.no_result"),
        "the empty-result message is shown"
      );
    assert
      .dom(".email-preview-digest .controls")
      .doesNotExist("an empty summary cannot be sent");
  });

  test("send digest form requires a destination email", async function (assert) {
    await visit("/admin/email/preview-digest");

    assert
      .dom(".email-preview-digest .controls")
      .exists("send email form is shown");

    assert
      .dom(".email-preview-digest .controls input[type='text']")
      .exists("an email text field is shown for sending this digest preview");

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
