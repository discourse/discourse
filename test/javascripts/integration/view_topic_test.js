integration("View Topic");

test("View a Topic", function() {

  visit("/t/internationalization-localization/280").then(function() {
    expect(2);

    ok(exists("#topic"), "The was rendered");
    ok(exists("#topic .topic-post"), "The topic has posts");
  });

});
