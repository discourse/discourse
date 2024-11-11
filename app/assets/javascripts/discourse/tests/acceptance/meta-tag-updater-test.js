import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Meta Tag Updater", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/about", () => helper.response({}));
  });

  test("updates OG title and URL", async function (assert) {
    await visit("/");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );
    await click("a[href='/about']");

    assert
      .dom("meta[property='og:title']", document)
      .hasAttribute("content", document.title, "updates OG title");
    assert
      .dom("meta[property='og:url']", document)
      .hasAttribute("content", /\/about$/, "updates OG URL");
    assert
      .dom("meta[name='twitter:title']", document)
      .hasAttribute("content", document.title, "updates Twitter title");
    assert
      .dom("meta[name='twitter:url']", document)
      .hasAttribute("content", /\/about$/, "updates Twitter URL");
    assert
      .dom("link[rel='canonical']", document)
      .hasAttribute("href", /\/about$/, "updates the canonical URL");
  });
});
