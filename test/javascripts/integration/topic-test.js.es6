integration("View Topic");

test("Enter a Topic", () => {
  visit("/t/internationalization-localization/280");
  andThen(() => {
    ok(exists("#topic"), "The topic was rendered");
    ok(exists("#topic .post-cloak"), "The topic has cloaked posts");
  });
});

test("Enter without an id", () => {
  visit("/t/internationalization-localization");
  andThen(() => {
    ok(exists("#topic"), "The topic was rendered");
  });
});
