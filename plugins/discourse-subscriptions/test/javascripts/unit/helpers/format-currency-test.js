/* eslint-disable qunit/no-assert-equal */
/* eslint-disable qunit/no-loose-assertions */
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import formatCurrency from "discourse/plugins/discourse-subscriptions/discourse/helpers/format-currency";

module("Subscriptions | Unit | Helper | format-currency", function (hooks) {
  setupTest(hooks);

  test("formats USD correctly", function (assert) {
    const result = formatCurrency("USD", 338.2);
    assert.equal(result, "$338.20", "Formats USD correctly");
  });

  test("rounds correctly", function (assert) {
    const result = formatCurrency("USD", 338.289);
    assert.equal(result, "$338.29", "Rounds correctly");
  });
});
