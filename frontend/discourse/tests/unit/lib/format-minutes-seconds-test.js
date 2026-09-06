import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { formatMinutesSeconds } from "discourse/lib/formatter";

module("Unit | Lib | formatMinutesSeconds", function (hooks) {
  setupTest(hooks);

  test("formats whole seconds below a minute as Xs", function (assert) {
    assert.strictEqual(formatMinutesSeconds(0), "0s");
    assert.strictEqual(formatMinutesSeconds(59), "59s");
  });

  test("formats seconds with optional subsecond precision", function (assert) {
    assert.strictEqual(
      formatMinutesSeconds(0, { subsecondPrecision: 2 }),
      "0s"
    );
    assert.strictEqual(
      formatMinutesSeconds(0.001, { subsecondPrecision: 2 }),
      "< 0.01s"
    );
    assert.strictEqual(
      formatMinutesSeconds(0.126, { subsecondPrecision: 2 }),
      "0.13s"
    );
    assert.strictEqual(
      formatMinutesSeconds(1.99, { subsecondPrecision: 2 }),
      "1s"
    );
  });

  test("formats a minute or more as Xm Ys with both units", function (assert) {
    assert.strictEqual(formatMinutesSeconds(60), "1m 0s");
    assert.strictEqual(formatMinutesSeconds(107), "1m 47s");
    assert.strictEqual(formatMinutesSeconds(1800), "30m 0s");
    assert.strictEqual(
      formatMinutesSeconds(60.99, { subsecondPrecision: 2 }),
      "1m 0s"
    );
  });
});
