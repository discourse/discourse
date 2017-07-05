import { acceptance } from "helpers/qunit-helpers";
acceptance("Unknown");

QUnit.test("Unknown URL", assert => {
  assert.expect(1);
  visit("/url-that-doesn't-exist");
  andThen(() => {
    assert.ok(exists(".page-not-found"), "The not found content is present");
  });
});
