import { isLTR, isRTL } from "discourse/lib/text-direction";
import { module, test } from "qunit";

module("Unit | Utility | text-direction", function () {
  test("isRTL", function (assert) {
    // Hebrew
    assert.strictEqual(isRTL("זה מבחן"), true);

    // Arabic
    assert.strictEqual(isRTL("هذا اختبار"), true);

    // Persian
    assert.strictEqual(isRTL("این یک امتحان است"), true);

    assert.strictEqual(isRTL("This is a test"), false);
    assert.strictEqual(isRTL(""), false);
  });

  test("isLTR", function (assert) {
    assert.strictEqual(isLTR("This is a test"), true);
    assert.strictEqual(isLTR("זה מבחן"), false);
  });
});
