import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - Email Templates - URL filters", function (needs) {
  needs.user();
  needs.settings({
    available_locales: [{ name: "English", value: "en" }],
    default_locale: "en",
  });

  needs.pretender((server, helper) => {
    server.get("/admin/email/templates/user_notifications.admin_login", () =>
      helper.response({
        email_template: {
          id: "user_notifications.admin_login",
          title: "Admin login",
          subject: "Subject",
          body: "Body",
          interpolation_keys: [],
          can_revert: false,
        },
      })
    );
    server.get("/admin/email/templates", () =>
      helper.response({
        email_templates: [
          {
            id: "user_notifications.admin_login",
            title: "Admin Login",
            can_revert: true,
          },
          {
            id: "user_notifications.signup",
            title: "Signup",
            can_revert: true,
          },
          {
            id: "user_notifications.account_created",
            title: "Account Created",
            can_revert: false,
          },
        ],
      })
    );
  });

  test("links the saved template to its email preview", async function (assert) {
    await visit("/admin/email/templates/user_notifications.admin_login");
    assert
      .dom(".email-template__preview")
      .hasAttribute(
        "href",
        "/admin/email/preview?email_type=template%3Auser_notifications.admin_login",
        "opens the saved template in the preview tool"
      );
  });

  test("seeds and updates the URL filters", async function (assert) {
    await visit("/admin/email/templates?filter=login&overridden=true");

    assert.dom(".d-filter-controls__input").hasValue("login");
    assert.dom("#toggle-overridden").isChecked();
    assert.dom("tr.email-templates-list__row").exists({ count: 1 });

    await fillIn(".d-filter-controls__input", "sign");
    assert.strictEqual(
      currentURL(),
      "/admin/email/templates?filter=sign&overridden=true"
    );

    await click("#toggle-overridden");
    assert.strictEqual(currentURL(), "/admin/email/templates?filter=sign");
    assert.dom("tr.email-templates-list__row").exists({ count: 1 });
  });

  test("does not retain overridden state across visits", async function (assert) {
    await visit("/admin/email/templates?overridden=true");
    assert.dom("#toggle-overridden").isChecked();

    await visit("/admin/customize/site_texts");
    await visit("/admin/email/templates");

    assert.dom("#toggle-overridden").isNotChecked();
    assert.dom("tr.email-templates-list__row").exists({ count: 3 });
  });
});
