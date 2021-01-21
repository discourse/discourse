import { isLTR, isRTL } from "discourse/lib/text-direction";
import { module, test } from "qunit";

module("Unit | Utility | text-direction", function () {
  test("isRTL", function (assert) {
    // Hebrew
    assert.equal(isRTL("זה מבחן"), true);

    // Arabic
    assert.equal(isRTL("هذا اختبار"), true);

    // Persian
    assert.equal(isRTL("این یک امتحان است"), true);

    assert.equal(isRTL("This is a test"), false);
    assert.equal(isRTL(""), false);
  });

  test("isLTR", function (assert) {
    assert.equal(isLTR("This is a test"), true);
    assert.equal(isLTR("זה מבחן"), false);
  });
});
