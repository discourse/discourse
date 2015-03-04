integration("User Card");

test("card", function() {
  visit('/');

  ok(invisible('#user-card'), 'user card is invisible by default');
  click('a[data-user-card=eviltrout]:first');

  andThen(function() {
    ok(visible('#user-card'), 'card should appear');
  });

});
