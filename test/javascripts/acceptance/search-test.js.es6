import { acceptance, logIn } from "helpers/qunit-helpers";
acceptance("Search");

QUnit.test("search", assert => {
  visit("/");

  click("#search-button");

  andThen(() => {
    assert.ok(exists("#search-term"), "it shows the search bar");
    assert.ok(!exists(".search-menu .results ul li"), "no results by default");
  });

  fillIn("#search-term", "dev");
  keyEvent("#search-term", "keyup", 16);
  andThen(() => {
    assert.ok(exists(".search-menu .results ul li"), "it shows results");
  });

  click(".show-help");

  andThen(() => {
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
});

QUnit.test("search for a tag", assert => {
  visit("/");

  click("#search-button");

  fillIn("#search-term", "evil");
  keyEvent("#search-term", "keyup", 16);
  andThen(() => {
    assert.ok(exists(".search-menu .results ul li"), "it shows results");
  });
});

QUnit.test("search scope checkbox", assert => {
  visit("/c/bug");
  click("#search-button");
  andThen(() => {
    assert.ok(
      exists(".search-context input:checked"),
      "scope to category checkbox is checked"
    );
  });
  click("#search-button");

  visit("/t/internationalization-localization/280");
  click("#search-button");
  andThen(() => {
    assert.not(
      exists(".search-context input:checked"),
      "scope to topic checkbox is not checked"
    );
  });
  click("#search-button");

  visit("/u/eviltrout");
  click("#search-button");
  andThen(() => {
    assert.ok(
      exists(".search-context input:checked"),
      "scope to user checkbox is checked"
    );
  });
});

QUnit.test("Search with context", assert => {
  visit("/t/internationalization-localization/280/1");

  click("#search-button");
  fillIn("#search-term", "dev");
  click(".search-context input[type='checkbox']");
  keyEvent("#search-term", "keyup", 16);

  andThen(() => {
    assert.ok(exists(".search-menu .results ul li"), "it shows results");

    assert.ok(
      exists(".cooked span.highlight-strong"),
      "it should highlight the search term"
    );
  });

  visit("/");
  click("#search-button");

  andThen(() => {
    assert.ok(!exists(".search-context input[type='checkbox']"));
  });

  visit("/t/internationalization-localization/280/1");
  click("#search-button");

  andThen(() => {
    assert.ok(!$(".search-context input[type=checkbox]").is(":checked"));
  });
});

QUnit.test("Right filters are shown to anonymous users", assert => {
  const inSelector = selectKit(".select-kit#in");

  visit("/search?expanded=true");

  inSelector.expand();

  andThen(() => {
    assert.ok(inSelector.rowByValue("first").exists());
    assert.ok(inSelector.rowByValue("pinned").exists());
    assert.ok(inSelector.rowByValue("unpinned").exists());
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

QUnit.test("Right filters are shown to logged-in users", assert => {
  const inSelector = selectKit(".select-kit#in");

  logIn();
  Discourse.reset();
  visit("/search?expanded=true");

  inSelector.expand();

  andThen(() => {
    assert.ok(inSelector.rowByValue("first").exists());
    assert.ok(inSelector.rowByValue("pinned").exists());
    assert.ok(inSelector.rowByValue("unpinned").exists());
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
