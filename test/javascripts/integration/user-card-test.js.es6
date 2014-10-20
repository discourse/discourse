integration("User Card");

test("card", function() {
  visit('/');

  ok(find('#user-card:visible').length === 0, 'user card is invisible by default');
  click('a[data-user-card=eviltrout]:first');

  andThen(function() {
    ok(find('#user-card:visible').length === 1, 'card should appear');
  });

});
