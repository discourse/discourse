import { acceptance } from "helpers/qunit-helpers";

const CONNECTOR = 'javascripts/single-test/connectors/user-profile-primary/hello';
acceptance("Plugin Outlet - Single Template", {
  setup() {
    Ember.TEMPLATES[CONNECTOR] = Ember.HTMLBars.compile(
      `<span class='hello-username'>{{model.username}}</span>
        <button class='hello-check-email' {{action "checkEmail" model}}></button>
        <span class='hello-email'>{{model.email}}</span>`
    );
  },

  teardown() {
    delete Ember.TEMPLATES[CONNECTOR];
  }
});

test("Renders a template into the outlet", assert => {
  visit("/users/eviltrout");
  andThen(() => {
    assert.ok(find('.user-profile-primary-outlet.hello').length === 1, 'it has class names');
    assert.equal(find('.hello-username').text(), 'eviltrout', 'it renders into the outlet');
  });
  click('.hello-check-email');
  andThen(() => {
    assert.equal(find('.hello-email').text(), 'eviltrout@example.com', 'actions delegate properly');
  });
});
