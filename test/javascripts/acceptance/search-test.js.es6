import { acceptance } from "helpers/qunit-helpers";
acceptance("Search");

test("search", (assert) => {
  visit("/");

  click('#search-button');

  andThen(() => {
    assert.ok(exists('#search-term'), 'it shows the search bar');
    assert.ok(!exists('#search-dropdown .results ul li'), 'no results by default');
  });

  // TODO need to change the way Discourse.ajax is stubbed so it has the .abort method
  // fillIn('#search-term', 'dev');
  // andThen(() => {
  //   assert.ok(exists('#search-dropdown .results ul li'), 'it shows results');
  // });
});
