import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Category 404", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/c/category-does-not-exist/find_by_slug.json", () => {
      return helper.response(404, {
        errors: ["The requested URL or resource could not be found."],
        error_type: "not_found",
        extras: { html: "<div class='page-not-found'>not found</div>" },
      });
    });
  });

  test("Navigating to a bad category link does not break the router", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click('[data-for-test="category-404"]');
    assert.strictEqual(currentURL(), "/404");

    // See that we can navigate away
    await click("#site-logo");
    assert.strictEqual(currentURL(), "/");
  });
});

acceptance("Unknown", function (needs) {
  const urls = {
    "/viewtopic.php?f=8&t=280": "/t/internationalization-localization/280",
    "/another-url-for-faq": "/faq",
  };

  needs.pretender((server, helper) => {
    server.get("/permalink-check.json", (request) => {
      let url = urls[request.queryParams.path];
      if (url) {
        return helper.response({
          found: true,
          internal: true,
          target_url: url,
        });
      } else {
        return helper.response({
          found: false,
          html: "<div class='page-not-found'>not found</div>",
        });
      }
    });
  });

  test("Permalink Unknown URL", async function (assert) {
    await visit("/url-that-doesn't-exist");
    assert.dom(".page-not-found").exists("the not found content is present");
  });

  test("Permalink URL to a Topic", async function (assert) {
    await visit("/viewtopic.php?f=8&t=280");
    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280"
    );
  });

  test("Permalink URL to a static page", async function (assert) {
    await visit("/another-url-for-faq");
    assert.strictEqual(currentURL(), "/faq");
  });
});
