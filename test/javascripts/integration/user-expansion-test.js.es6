integration("User Expansion");

test("expansion", function() {
  visit('/');

  ok(find('#user-expansion:visible').length === 0, 'user expansion is invisible by default');
  click('a[data-user-expand=eviltrout]:first');

  andThen(function() {
    ok(find('#user-expansion:visible').length === 1, 'expansion should appear');
  });

});
