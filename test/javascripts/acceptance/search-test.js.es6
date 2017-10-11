import { acceptance, logIn } from "helpers/qunit-helpers";
acceptance("Search");

QUnit.test("search", (assert) => {
  visit("/");

  click('#search-button');

  andThen(() => {
    assert.ok(exists('#search-term'), 'it shows the search bar');
    assert.ok(!exists('.search-menu .results ul li'), 'no results by default');
  });

  fillIn('#search-term', 'dev');
  keyEvent('#search-term', 'keyup', 16);
  andThen(() => {
    assert.ok(exists('.search-menu .results ul li'), 'it shows results');
  });

  click('.show-help');

  andThen(() => {
    assert.equal(find('.full-page-search').val(), 'dev', 'it shows the search term');
    assert.ok(exists('.search-advanced-options'), 'advanced search is expanded');
  });
});

QUnit.test("search for a tag", (assert) => {
  visit("/");

  click('#search-button');

  fillIn('#search-term', 'evil');
  keyEvent('#search-term', 'keyup', 16);
  andThen(() => {
    assert.ok(exists('.search-menu .results ul li'), 'it shows results');
  });
});

QUnit.test("search scope checkbox", assert => {
  visit("/c/bug");
  click('#search-button');
  andThen(() => {
    assert.ok(exists('.search-context input:checked'), 'scope to category checkbox is checked');
  });
  click('#search-button');

  visit("/t/internationalization-localization/280");
  click('#search-button');
  andThen(() => {
    assert.not(exists('.search-context input:checked'), 'scope to topic checkbox is not checked');
  });
  click('#search-button');

  visit("/u/eviltrout");
  click('#search-button');
  andThen(() => {
    assert.ok(exists('.search-context input:checked'), 'scope to user checkbox is checked');
  });
});

QUnit.test("Search with context", assert => {
  visit("/t/internationalization-localization/280/1");

  click('#search-button');
  fillIn('#search-term', 'dev');
  click(".search-context input[type='checkbox']");
  keyEvent('#search-term', 'keyup', 16);

  andThen(() => {
    assert.ok(exists('.search-menu .results ul li'), 'it shows results');
  });

  visit("/");
  click('#search-button');

  andThen(() => {
    assert.ok(!exists(".search-context input[type='checkbox']"));
  });

  visit("/t/internationalization-localization/280/1");
  click('#search-button');

  andThen(() => {
    assert.ok(!$('.search-context input[type=checkbox]').is(":checked"));
  });
});

QUnit.test("Right filters are shown to anonymous users", assert => {
  visit("/search?expanded=true");

  expandSelectBox(".select-box-kit#in");

  andThen(() => {
    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=first]'));
    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=pinned]'));
    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=unpinned]'));
    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=wiki]'));
    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=images]'));

    assert.notOk(exists('.select-box-kit#in .select-box-kit-row[data-value=unseen]'));
    assert.notOk(exists('.select-box-kit#in .select-box-kit-row[data-value=posted]'));
    assert.notOk(exists('.select-box-kit#in .select-box-kit-row[data-value=watching]'));
    assert.notOk(exists('.select-box-kit#in .select-box-kit-row[data-value=tracking]'));
    assert.notOk(exists('.select-box-kit#in .select-box-kit-row[data-value=bookmarks]'));

    assert.notOk(exists('.search-advanced-options .in-likes'));
    assert.notOk(exists('.search-advanced-options .in-private'));
    assert.notOk(exists('.search-advanced-options .in-seen'));
  });
});

QUnit.test("Right filters are shown to logged-in users", assert => {
  logIn();
  Discourse.reset();
  visit("/search?expanded=true");

  expandSelectBox(".select-box-kit#in");

  andThen(() => {
    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=first]'));
    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=pinned]'));
    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=unpinned]'));
    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=wiki]'));
    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=images]'));

    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=unseen]'));
    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=posted]'));
    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=watching]'));
    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=tracking]'));
    assert.ok(exists('.select-box-kit#in .select-box-kit-row[data-value=bookmarks]'));

    assert.ok(exists('.search-advanced-options .in-likes'));
    assert.ok(exists('.search-advanced-options .in-private'));
    assert.ok(exists('.search-advanced-options .in-seen'));
  });
});
