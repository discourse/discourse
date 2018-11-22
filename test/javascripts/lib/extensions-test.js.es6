QUnit.module("extensions");

QUnit.test("Array.groupBy", assert => {
  assert.deepEqual(["one", "two", "three"].groupBy("length"), {
    "3": ["one", "two"],
    "5": ["three"]
  });
});
