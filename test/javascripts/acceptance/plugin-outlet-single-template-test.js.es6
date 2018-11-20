import { acceptance } from "helpers/qunit-helpers";

const CONNECTOR =
  "javascripts/single-test/connectors/user-profile-primary/hello";
acceptance("Plugin Outlet - Single Template", {
  beforeEach() {
    Ember.TEMPLATES[CONNECTOR] = Ember.HTMLBars.compile(
      `<span class='hello-username'>{{model.username}}</span>`
    );
  },

  afterEach() {
    delete Ember.TEMPLATES[CONNECTOR];
  }
});

QUnit.test("Renders a template into the outlet", async assert => {
  await visit("/u/eviltrout");
  assert.ok(
    find(".user-profile-primary-outlet.hello").length === 1,
    "it has class names"
  );
  assert.equal(
    find(".hello-username").text(),
    "eviltrout",
    "it renders into the outlet"
  );
});
