import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit, currentURL } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Unknown", function (needs) {
  const urls = {
    "viewtopic.php": "/t/internationalization-localization/280",
    "not-the-url-for-faq": "/faq",
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

  test("Permalink Unknown URL", async (assert) => {
    await visit("/url-that-doesn't-exist");
    assert.ok(exists(".page-not-found"), "The not found content is present");
  });

  test("Permalink URL to a Topic", async (assert) => {
    await visit("/viewtopic.php?f=8&t=280");
    assert.equal(currentURL(), "/t/internationalization-localization/280");
  });

  test("Permalink URL to a static page", async (assert) => {
    await visit("/not-the-url-for-faq");
    assert.equal(currentURL(), "/faq");
  });
});
