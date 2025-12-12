import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { getReviewBadgeText } from "discourse/lib/sidebar/helpers/review-badge-helper";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Sidebar | Helpers | review-badge-helper", function (hooks) {
  setupTest(hooks);

  test("returns undefined when user has no reviewables", function (assert) {
    const currentUser = logIn(this.owner);
    currentUser.set("reviewable_count", 0);

    const result = getReviewBadgeText(currentUser);

    assert.strictEqual(result, undefined);
  });

  test("returns formatted badge text for single reviewable", function (assert) {
    const currentUser = logIn(this.owner);
    currentUser.set("reviewable_count", 1);

    const result = getReviewBadgeText(currentUser);

    assert.strictEqual(result, "1 pending");
  });

  test("returns formatted badge text for multiple reviewables", function (assert) {
    const currentUser = logIn(this.owner);
    currentUser.set("reviewable_count", 42);

    const result = getReviewBadgeText(currentUser);

    assert.strictEqual(result, "42 pending");
  });
});
