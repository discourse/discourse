import { acceptance } from "helpers/qunit-helpers";
acceptance("Topic - Anonymous");

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

test("Enter a 404 topic", assert => {
  visit("/t/not-found/404");
  andThen(() => {
    assert.ok(!exists("#topic"), "The topic was not rendered");
    assert.ok(find(".not-found").text() === "not found", "it renders the error message");
  });
});

test("Enter without access", assert => {
  visit("/t/i-dont-have-access/403");
  andThen(() => {
    assert.ok(!exists("#topic"), "The topic was not rendered");
    assert.ok(exists(".topic-error"), "An error message is displayed");
  });
});

test("Enter with 500 errors", assert => {
  visit("/t/throws-error/500");
  andThen(() => {
    assert.ok(!exists("#topic"), "The topic was not rendered");
    assert.ok(exists(".topic-error"), "An error message is displayed");
  });
});
