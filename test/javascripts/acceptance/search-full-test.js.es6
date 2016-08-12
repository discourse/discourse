import { acceptance } from "helpers/qunit-helpers";
acceptance("Search - Full Page");

test("perform various searches", assert => {
  visit("/search");

  andThen(() => {
    assert.ok(find('input.search').length > 0);
    assert.ok(find('.fps-topic').length === 0);
  });

  fillIn('.search input', 'none');
  click('.search .btn-primary');

  andThen(() => assert.ok(find('.fps-topic').length === 0), 'has no results');

  fillIn('.search input', 'posts');
  click('.search .btn-primary');

  andThen(() => assert.ok(find('.fps-topic').length === 1, 'has one post'));
});
