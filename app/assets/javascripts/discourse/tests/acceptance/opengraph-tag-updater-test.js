import { click, visit } from "@ember/test-helpers";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

acceptance("Opengraph Tag Updater", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/about", () => {
      return helper.response({});
    });
  });
  needs.site({
    anonymous_sidebar_sections: [
      {
        id: 111,
        title: "Community",
        links: [
          {
            id: 329,
            name: "Everything",
            value: "/latest",
            icon: "layer-group",
            external: false,
            segment: "primary",
          },
          {
            id: 331,
            name: "Info",
            value: "/about",
            icon: "info-circle",
            external: false,
            segment: "secondary",
          },
        ],
        slug: "community",
        public: true,
        system: true,
      },
    ],
  });

  test("updates OG title and URL", async function (assert) {
    await visit("/");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );
    await click("a[href='/about']");

    assert.strictEqual(
      document
        .querySelector("meta[property='og:title']")
        .getAttribute("content"),
      document.title,
      "it should update OG title"
    );
    assert.ok(
      document
        .querySelector("meta[property='og:url']")
        .getAttribute("content")
        .endsWith("/about"),
      "it should update OG URL"
    );
    assert.strictEqual(
      document
        .querySelector("meta[property='twitter:title']")
        .getAttribute("content"),
      document.title,
      "it should update OG title"
    );
    assert.ok(
      document
        .querySelector("meta[property='twitter:url']")
        .getAttribute("content")
        .endsWith("/about"),
      "it should update OG URL"
    );
  });
});
