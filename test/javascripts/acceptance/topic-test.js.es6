import { acceptance } from "helpers/qunit-helpers";
acceptance("View Topic");

test("Enter a Topic", () => {
  visit("/t/internationalization-localization/280/1");
  andThen(() => {
    ok(exists("#topic"), "The topic was rendered");
    ok(exists("#topic .cooked"), "The topic has cooked posts");
  });
});

test("Enter without an id", () => {
  visit("/t/internationalization-localization");
  andThen(() => {
    ok(exists("#topic"), "The topic was rendered");
  });
});
