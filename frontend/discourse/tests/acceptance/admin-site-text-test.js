import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - Site Texts", function (needs) {
  needs.user();
  needs.settings({
    available_locales: [{ name: "English", value: "en" }],
    default_locale: "en",
  });

  test("search for a key", async function (assert) {
    await visit("/admin/customize/site_texts");

    await fillIn(".site-text-search", "Test");

    assert.strictEqual(currentURL(), "/admin/customize/site_texts?q=Test");
    assert.dom(".site-text").exists();
    assert.dom(".site-text:not(.overridden)").exists();
    assert.dom(".site-text.overridden").exists();

    await click(".d-filter-controls__toggle-filters");

    // Only show overridden
    await click(".search-area .filter-options #toggle-overridden");
    assert.strictEqual(
      currentURL(),
      "/admin/customize/site_texts?overridden=true&q=Test"
    );

    assert.dom(".site-text:not(.overridden)").doesNotExist();
    assert.dom(".site-text.overridden").exists();
    await click(".search-area .filter-options #toggle-overridden");

    // Only show outdated
    await click(".search-area .filter-options #toggle-outdated");
    assert.strictEqual(
      currentURL(),
      "/admin/customize/site_texts?outdated=true&q=Test"
    );
  });

  test("edit and revert a site text by key", async function (assert) {
    await visit("/admin/customize/site_texts/site.test?locale=en");

    assert.dom(".edit-site-text__key").hasText("site.test");
    assert.dom(".saved").doesNotExist();
    assert.dom(".revert-site-text").doesNotExist();

    // Change the value
    await fillIn(".site-text-value", "New Test Value");
    await click(".save-changes");

    assert.dom(".saved").exists();
    assert.dom(".revert-site-text").exists();

    // Revert the changes
    await click(".revert-site-text");

    assert.dom("#dialog-holder .dialog-content").exists();

    await click("#dialog-holder .btn-primary");

    assert.dom(".saved").doesNotExist();
    assert.dom(".revert-site-text").doesNotExist();
  });

  test("save button disabled state", async function (assert) {
    await visit("/admin/customize/site_texts");

    await click('[data-site-text-id="site.test"] .site-text-edit');

    await click(".go-back");

    await click('[data-site-text-id="site.overridden"] .site-text-edit');
    assert.dom(".save-changes").hasAttribute("disabled");

    await fillIn(".site-text-value", "Some new value");
    assert.dom(".save-changes").doesNotHaveAttribute("disabled");
  });
});

acceptance("Admin - Site Texts - baseline", function (needs) {
  needs.user();
  needs.settings({
    available_locales: [{ name: "English", value: "en" }],
    default_locale: "en",
  });
  needs.pretender((server, helper) => {
    server.get("/admin/customize/site_texts", (request) => {
      let texts = [
        {
          id: "sample.outdated",
          value: "Old custom text",
          status: "outdated",
          overridden: true,
        },
        {
          id: "sample.invalid",
          value: "Invalid %{unknown}",
          status: "invalid_interpolation_keys",
          overridden: true,
        },
        {
          id: "sample.default",
          value: "Default text",
          status: "up_to_date",
          overridden: false,
        },
      ];
      if (request.queryParams.overridden === "true") {
        texts = texts.filter((text) => text.overridden);
      }
      return helper.response({ site_texts: texts, extras: {} });
    });
  });

  test("reverting invalid text clears its warning and restores the default preview", async function (assert) {
    const siteText = {
      id: "sample.invalid",
      value: "Invalid %{unknown}",
      status: "invalid_interpolation_keys",
      overridden: true,
      can_revert: true,
      new_default: "Original text",
      interpolation_keys: [],
    };
    pretender.get("/admin/customize/site_texts/sample.invalid", () =>
      response({ site_text: siteText })
    );
    pretender.delete("/admin/customize/site_texts/sample.invalid", () =>
      response({
        site_text: {
          ...siteText,
          value: "Original text",
          status: "up_to_date",
          overridden: false,
          can_revert: false,
          new_default: null,
        },
      })
    );
    await visit("/admin/customize/site_texts/sample.invalid?locale=en");
    assert
      .dom('.edit-site-text .outdated[role="status"]')
      .exists("invalid text displays a warning");
    await click(".revert-site-text");
    await click("#dialog-holder .btn-primary");
    assert
      .dom('.edit-site-text .outdated[role="status"]')
      .doesNotExist("reverting clears the warning");
    assert
      .dom(".edit-site-text__default p")
      .hasText("Original text", "the default preview remains available");
    assert
      .dom(".site-text-value")
      .hasValue("Original text", "the editor uses the default");
  });

  test("can reset an active filter hidden for the selected language", async function (assert) {
    await visit("/admin/customize/site_texts?q=sample&untranslated=true");
    assert
      .dom("#toggle-untranslated")
      .doesNotExist("English has no untranslated checkbox");
    assert
      .dom(".d-filter-controls__toggle-filters")
      .hasText("Filters (1)", "the active query filter is counted");
    await click(".site-texts__reset-filters");
    assert.false(
      currentURL().includes("untranslated=true"),
      "reset removes the hidden filter"
    );
    assert
      .dom(".site-text-search")
      .hasValue("sample", "reset preserves search");
  });

  test("shows distinct statuses and preserves combined filters when resetting", async function (assert) {
    await visit("/admin/customize/site_texts?q=sample");
    assert
      .dom('[data-site-text-id="sample.outdated"] .site-text__status')
      .hasText("Outdated", "outdated status is explicit");
    assert
      .dom('[data-site-text-id="sample.invalid"] .site-text__status')
      .hasText("Invalid", "invalid status is explicit");
    assert.dom("#toggle-overridden").doesNotExist("filters start collapsed");
    await click(".d-filter-controls__toggle-filters");
    await click("#toggle-overridden");
    await click("#toggle-outdated");
    assert.dom("#toggle-overridden").isChecked("overridden remains selected");
    assert.dom("#toggle-outdated").isChecked("outdated can be combined");
    assert.true(
      currentURL().includes("overridden=true"),
      "overridden is stored in the URL"
    );
    assert.true(
      currentURL().includes("outdated=true"),
      "outdated is stored in the URL"
    );
    await click(".site-texts__reset-filters");
    assert.dom("#toggle-overridden").isNotChecked("overridden is reset");
    assert.dom("#toggle-outdated").isNotChecked("outdated is reset");
    assert
      .dom(".site-text-search")
      .hasValue("sample", "reset preserves search");
    assert.dom(".site-text").exists({ count: 3 }, "reset restores all rows");
  });
});
