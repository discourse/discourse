import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { postVotingEnabledForCategory } from "discourse/plugins/discourse-post-voting/discourse/lib/post-voting-utilities";

// `post_voting_allowed` is resolved server-side, so the client only has to
// respect the mode and read the serialized boolean.
function settings(mode) {
  return { post_voting_category_mode: mode };
}

function category(allowed) {
  return { id: 1, post_voting_allowed: allowed };
}

module("Unit | Lib | post-voting-utilities", function (hooks) {
  setupTest(hooks);

  test("postVotingEnabledForCategory allows everything in all_categories mode", function (assert) {
    const mode = settings("all_categories");

    assert.true(
      postVotingEnabledForCategory(category(false), mode),
      "even a category the server marked as not allowed"
    );
    assert.true(
      postVotingEnabledForCategory(null, mode),
      "even with no category chosen yet"
    );
  });

  test("postVotingEnabledForCategory follows the server's decision in opt_in mode", function (assert) {
    const mode = settings("opt_in");

    assert.true(
      postVotingEnabledForCategory(category(true), mode),
      "an allowed category"
    );
    assert.false(
      postVotingEnabledForCategory(category(false), mode),
      "a category that has not opted in"
    );
  });

  test("postVotingEnabledForCategory follows the server's decision in opt_out mode", function (assert) {
    const mode = settings("opt_out");

    assert.true(
      postVotingEnabledForCategory(category(true), mode),
      "a category that has not opted out"
    );
    assert.false(
      postVotingEnabledForCategory(category(false), mode),
      "a category that has opted out"
    );
  });

  test("postVotingEnabledForCategory rejects a missing category outside all_categories mode", function (assert) {
    assert.false(
      postVotingEnabledForCategory(null, settings("opt_in")),
      "a null category"
    );
    assert.false(
      postVotingEnabledForCategory(undefined, settings("opt_out")),
      "an undefined category"
    );
    assert.false(
      postVotingEnabledForCategory({ id: 1 }, settings("opt_in")),
      "a category the server did not serialize a decision for"
    );
  });
});
