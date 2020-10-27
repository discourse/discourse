import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import searchFixtures from "discourse/tests/fixtures/search-fixtures";

acceptance("Search - Anonymous", function (needs) {
  let calledEmpty = false;

  needs.pretender((server, helper) => {
    server.get("/search/query", (request) => {
      if (!request.queryParams["search_context[type]"]) {
        calledEmpty = true;
      }

      return helper.response(searchFixtures["search/query"]);
    });
  });

  test("search", async (assert) => {
    await visit("/");

    await click("#search-button");

    assert.ok(exists("#search-term"), "it shows the search bar");
    assert.ok(!exists(".search-menu .results ul li"), "no results by default");

    await fillIn("#search-term", "dev");
    await keyEvent("#search-term", "keyup", 16);
    assert.ok(exists(".search-menu .results ul li"), "it shows results");
    assert.ok(
      exists(".search-menu .results ul li .topic-title[data-topic-id]"),
      "topic has data-topic-id"
    );

    await click(".show-help");

    assert.equal(
      find(".full-page-search").val(),
      "dev",
      "it shows the search term"
    );
    assert.ok(
      exists(".search-advanced-options"),
      "advanced search is expanded"
    );
  });

  test("search for a tag", async (assert) => {
    await visit("/");

    await click("#search-button");

    await fillIn("#search-term", "evil");
    await keyEvent("#search-term", "keyup", 16);
    assert.ok(exists(".search-menu .results ul li"), "it shows results");
  });

  test("search scope checkbox", async (assert) => {
    await visit("/tag/important");
    await click("#search-button");
    assert.ok(
      exists(".search-context input:checked"),
      "scope to tag checkbox is checked"
    );
    await click("#search-button");

    await visit("/c/bug");
    await click("#search-button");
    assert.ok(
      exists(".search-context input:checked"),
      "scope to category checkbox is checked"
    );
    await click("#search-button");

    await visit("/t/internationalization-localization/280");
    await click("#search-button");
    assert.not(
      exists(".search-context input:checked"),
      "scope to topic checkbox is not checked"
    );
    await click("#search-button");

    await visit("/u/eviltrout");
    await click("#search-button");
    assert.ok(
      exists(".search-context input:checked"),
      "scope to user checkbox is checked"
    );
  });

  test("Search with context", async (assert) => {
    await visit("/t/internationalization-localization/280/1");

    await click("#search-button");
    await fillIn("#search-term", "a proper");
    await click(".search-context input[type='checkbox']");
    await keyEvent("#search-term", "keyup", 16);

    assert.ok(exists(".search-menu .results ul li"), "it shows results");

    const highlighted = [];

    find("#post_7 span.highlighted").map((_, span) => {
      highlighted.push(span.innerText);
    });

    assert.deepEqual(
      highlighted,
      ["a proper"],
      "it should highlight the post with the search terms correctly"
    );

    calledEmpty = false;
    await visit("/");
    await click("#search-button");

    assert.ok(!exists(".search-context input[type='checkbox']"));
    assert.ok(calledEmpty, "it triggers a new search");

    await visit("/t/internationalization-localization/280/1");
    await click("#search-button");

    assert.ok(!$(".search-context input[type=checkbox]").is(":checked"));
  });

  test("Right filters are shown to anonymous users", async (assert) => {
    const inSelector = selectKit(".select-kit#in");

    await visit("/search?expanded=true");

    await inSelector.expand();

    assert.ok(inSelector.rowByValue("first").exists());
    assert.ok(inSelector.rowByValue("pinned").exists());
    assert.ok(inSelector.rowByValue("wiki").exists());
    assert.ok(inSelector.rowByValue("images").exists());

    assert.notOk(inSelector.rowByValue("unseen").exists());
    assert.notOk(inSelector.rowByValue("posted").exists());
    assert.notOk(inSelector.rowByValue("watching").exists());
    assert.notOk(inSelector.rowByValue("tracking").exists());
    assert.notOk(inSelector.rowByValue("bookmarks").exists());

    assert.notOk(exists(".search-advanced-options .in-likes"));
    assert.notOk(exists(".search-advanced-options .in-private"));
    assert.notOk(exists(".search-advanced-options .in-seen"));
  });
});

acceptance("Search - Authenticated", function (needs) {
  needs.user();

  test("Right filters are shown to logged-in users", async (assert) => {
    const inSelector = selectKit(".select-kit#in");

    await visit("/search?expanded=true");

    await inSelector.expand();

    assert.ok(inSelector.rowByValue("first").exists());
    assert.ok(inSelector.rowByValue("pinned").exists());
    assert.ok(inSelector.rowByValue("wiki").exists());
    assert.ok(inSelector.rowByValue("images").exists());

    assert.ok(inSelector.rowByValue("unseen").exists());
    assert.ok(inSelector.rowByValue("posted").exists());
    assert.ok(inSelector.rowByValue("watching").exists());
    assert.ok(inSelector.rowByValue("tracking").exists());
    assert.ok(inSelector.rowByValue("bookmarks").exists());

    assert.ok(exists(".search-advanced-options .in-likes"));
    assert.ok(exists(".search-advanced-options .in-private"));
    assert.ok(exists(".search-advanced-options .in-seen"));
  });
});

acceptance("Search - with tagging enabled", function (needs) {
  needs.user();
  needs.settings({ tagging_enabled: true });

  test("displays tags", async (assert) => {
    await visit("/");

    await click("#search-button");

    await fillIn("#search-term", "dev");
    await keyEvent("#search-term", "keyup", 16);

    const tags = find(".search-menu .results ul li:eq(0) .discourse-tags")
      .text()
      .trim();

    assert.equal(tags, "dev slow");
  });
});
