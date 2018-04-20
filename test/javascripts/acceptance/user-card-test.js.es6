import { acceptance } from "helpers/qunit-helpers";
acceptance("User Card");

QUnit.test("card", assert => {
  visit('/');

  assert.ok(invisible('#user-card'), 'user card is invisible by default');
  click('a[data-user-card=eviltrout]:first');

  andThen(() => {
    assert.ok(visible('#user-card'), 'card should appear');
  });

});


QUnit.test("group card", assert => {
  visit('/t/301/1');

  assert.ok(invisible('#group-card'), 'user card is invisible by default');
  click('a.mention-group:first');

  andThen(() => {
    assert.ok(visible('#group-card'), 'card should appear');
  });

});
