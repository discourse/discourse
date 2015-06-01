import { acceptance } from "helpers/qunit-helpers";
acceptance("Modal");

test("modal", () => {
  visit('/');

  andThen(() => {
    ok(find('#discourse-modal:visible').length === 0, 'there is no modal at first');
  });

  click('.login-button');
  andThen(() => {
    ok(find('#discourse-modal:visible').length === 1, 'modal should appear');
  });

  click('.modal-outer-container');
  andThen(() => {
    ok(find('#discourse-modal:visible').length === 0, 'modal should disappear when you click outside');
  });

  click('.login-button');
  andThen(() => {
    ok(find('#discourse-modal:visible').length === 1, 'modal should reappear');
  });

  keyEvent('#main-outlet', 'keydown', 27);
  andThen(() => {
    ok(find('#discourse-modal:visible').length === 0, 'ESC should close the modal');
  });
});
