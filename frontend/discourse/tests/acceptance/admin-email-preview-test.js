import { click, fillIn, visit, waitUntil } from "@ember/test-helpers";
import { test } from "qunit";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - email-preview", function (needs) {
  needs.user();
  let digestRequests = [];
  needs.hooks.beforeEach(() => (digestRequests = []));
  needs.pretender((server, helper) => {
    server.get("/u/search/users", () =>
      helper.response({
        users: [{ username: "bob", name: "Bob", avatar_template: "/a/{size}" }],
      })
    );
    server.get("/admin/email/preview-digest.json", (request) => {
      digestRequests.push(request.queryParams);
      return helper.response(200, {
        html_content: "<span>Hello world</span>",
        text_content: "<span>Not actually html</span>",
      });
    });
  });

  test("preview rendering", async function (assert) {
    await visit("/admin/email/preview-digest");
    const iframe = document.querySelector(".preview-output iframe");

    // Rendered as a separate document, so Ember's built-in waiters don't work properly
    await waitUntil(() =>
      iframe.contentWindow.document.body?.querySelector("span")
    );

    const iframeBody = iframe.contentWindow.document.body;

    assert
      .dom("span", iframeBody)
      .hasText("Hello world", "html content is rendered inside iframe");

    await click("a.show-text-link");
    assert
      .dom(".preview-output pre")
      .hasText(
        "<span>Not actually html</span>",
        "text content is escaped correctly"
      );
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

  test("previews the digest for a picked user with the new controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    await visit("/admin/email/preview-digest");

    const user = dSelect(".email-preview .d-select");
    await user.search("bo");
    await user.selectByName("bob");
    await click(".digest-refresh-button");

    assert.strictEqual(digestRequests.at(-1).username, "bob");
  });
});
