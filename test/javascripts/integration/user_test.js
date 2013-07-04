integration("User");

test("Profile", function() {

  visit("/users/eviltrout").then(function() {
    expect(2);

    ok(exists(".user-heading"), "The heading is rendered");
    ok(exists("#user-stream"), "The stream is rendered");
  });

});
