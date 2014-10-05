integration("Modal");

test("modal", function() {
  visit('/');

  andThen(function() {
    ok(find('#discourse-modal:visible').length === 0, 'there is no modal at first');
  });

  click('.login-button');
  andThen(function() {
    ok(find('#discourse-modal:visible').length === 1, 'modal should appear');
  });

  click('.modal-outer-container');
  andThen(function() {
    ok(find('#discourse-modal:visible').length === 0, 'modal should disappear when you click outside');
  });

  click('.login-button');
  andThen(function() {
    ok(find('#discourse-modal:visible').length === 1, 'modal should appear');
  });

  keyEvent('#main-outlet', 'keyup', 27);
  andThen(function() {
    ok(find('#discourse-modal:visible').length === 0, 'ESC should close the modal');
  });
});
