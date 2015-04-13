import { acceptance } from "helpers/qunit-helpers";
acceptance("User Card");

test("card", () => {
  visit('/');

  ok(invisible('#user-card'), 'user card is invisible by default');
  click('a[data-user-card=eviltrout]:first');

  andThen(() => {
    ok(visible('#user-card'), 'card should appear');
  });

});
