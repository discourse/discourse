import { acceptance } from "helpers/qunit-helpers";
acceptance("Unknown");

test("Unknown URL", () => {
  expect(1);
  visit("/url-that-doesn't-exist");
  andThen(() => {
    ok(exists(".page-not-found"), "The not found content is present");
  });
});
