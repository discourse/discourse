import { acceptance } from "helpers/qunit-helpers";
acceptance("Unknown");

QUnit.test("Unknown URL", async assert => {
  assert.expect(1);
  await visit("/url-that-doesn't-exist");
  assert.ok(exists(".page-not-found"), "The not found content is present");
});
