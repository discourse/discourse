import { isRTL, isLTR } from "discourse/lib/text-direction";

QUnit.module("lib:text-direction");

QUnit.test("isRTL", assert => {
  // Hebrew
  assert.equal(isRTL("זה מבחן"), true);

  // Arabic
  assert.equal(isRTL("هذا اختبار"), true);

  // Persian
  assert.equal(isRTL("این یک امتحان است"), true);

  assert.equal(isRTL("This is a test"), false);
  assert.equal(isRTL(""), false);
});

QUnit.test("isLTR", assert => {
  assert.equal(isLTR("This is a test"), true);
  assert.equal(isLTR("זה מבחן"), false);
});
