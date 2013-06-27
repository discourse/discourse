module("Discourse.Presence");

var testObj = Em.Object.createWithMixins(Discourse.Presence, {
  emptyString: "",
  nonEmptyString: "Evil Trout",
  emptyArray: [],
  nonEmptyArray: [1, 2, 3],
  age: 34
});

test("present", function() {
  ok(testObj.present('nonEmptyString'), "Non empty strings are present");
  ok(!testObj.present('emptyString'), "Empty strings are not present");
  ok(testObj.present('nonEmptyArray'), "Non Empty Arrays are present");
  ok(!testObj.present('emptyArray'), "Empty arrays are not present");
  ok(testObj.present('age'), "integers are present");
});

test("blank", function() {
  ok(testObj.blank('emptyString'), "Empty strings are blank");
  ok(!testObj.blank('nonEmptyString'), "Non empty strings are not blank");
  ok(testObj.blank('emptyArray'), "Empty arrays are blank");
  ok(!testObj.blank('nonEmptyArray'), "Non empty arrays are not blank");
  ok(testObj.blank('missing'), "Missing properties are blank");
});