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
  andThen(() => {
    assert.ok(exists('.search-menu .results ul li'), 'it shows results');
  });
});
