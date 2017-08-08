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

QUnit.test("in:likes, in:private, and in:seen filters are hidden to anonymous users", assert => {
  visit("/search?expanded=true");

  andThen(() => {
    assert.notOk(exists('.search-advanced-options .in-likes'));
    assert.notOk(exists('.search-advanced-options .in-private'));
    assert.notOk(exists('.search-advanced-options .in-seen'));
  });
});

QUnit.test("in:likes, in:private, and in:seen filters are available to logged in users", assert => {
  logIn();
  Discourse.reset();
  visit("/search?expanded=true");

  andThen(() => {
    assert.ok(exists('.search-advanced-options .in-likes'));
    assert.ok(exists('.search-advanced-options .in-private'));
    assert.ok(exists('.search-advanced-options .in-seen'));
  });
});

QUnit.test(`"I've not read", "I posted in", "I'm watching", "I'm tracking",
            "I've bookmarked" filters are hidden to anonymous users from the dropdown`, assert => {
  visit("/search?expanded=true");

  andThen(() => {
    assert.notOk(exists('select#in option[value=unseen]'));
    assert.notOk(exists('select#in option[value=posted]'));
    assert.notOk(exists('select#in option[value=watching]'));
    assert.notOk(exists('select#in option[value=tracking]'));
    assert.notOk(exists('select#in option[value=bookmarks]'));
  });
});

QUnit.test(`"I've not read", "I posted in", "I'm watching", "I'm tracking",
            "I've bookmarked" filters are available to logged in users in the dropdown`, assert => {
  logIn();
  Discourse.reset();
  visit("/search?expanded=true");

  andThen(() => {
    assert.ok(exists('select#in option[value=unseen]'));
    assert.ok(exists('select#in option[value=posted]'));
    assert.ok(exists('select#in option[value=watching]'));
    assert.ok(exists('select#in option[value=tracking]'));
    assert.ok(exists('select#in option[value=bookmarks]'));
  });
});
