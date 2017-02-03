import { acceptance } from "helpers/qunit-helpers";
acceptance("Search");

test("search", (assert) => {
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

test("search scope checkbox", () => {
  visit("/c/bug");
  click('#search-button');
  andThen(() => {
    ok(exists('.search-context input:checked'), 'scope to category checkbox is checked');
  });
  click('#search-button');

  visit("/t/internationalization-localization/280");
  click('#search-button');
  andThen(() => {
    not(exists('.search-context input:checked'), 'scope to topic checkbox is not checked');
  });
  click('#search-button');

  visit("/users/eviltrout");
  click('#search-button');
  andThen(() => {
    ok(exists('.search-context input:checked'), 'scope to user checkbox is checked');
  });
});

test("Search with context", assert => {
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
