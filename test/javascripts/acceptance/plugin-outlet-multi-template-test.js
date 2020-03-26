import { acceptance } from "helpers/qunit-helpers";
import { clearCache } from "discourse/lib/plugin-connectors";

const HELLO = "javascripts/multi-test/connectors/user-profile-primary/hello";
const GOODBYE =
  "javascripts/multi-test/connectors/user-profile-primary/goodbye";

acceptance("Plugin Outlet - Multi Template", {
  beforeEach() {
    clearCache();
    Ember.TEMPLATES[HELLO] = Ember.HTMLBars.compile(
      `<span class='hello-span'>Hello</span>`
    );
    Ember.TEMPLATES[GOODBYE] = Ember.HTMLBars.compile(
      `<span class='bye-span'>Goodbye</span>`
    );
  },

  afterEach() {
    delete Ember.TEMPLATES[HELLO];
    delete Ember.TEMPLATES[GOODBYE];
    clearCache();
  }
});

QUnit.test("Renders a template into the outlet", async assert => {
  await visit("/u/eviltrout");
  assert.ok(
    find(".user-profile-primary-outlet.hello").length === 1,
    "it has class names"
  );
  assert.ok(
    find(".user-profile-primary-outlet.goodbye").length === 1,
    "it has class names"
  );
  assert.equal(
    find(".hello-span").text(),
    "Hello",
    "it renders into the outlet"
  );
  assert.equal(
    find(".bye-span").text(),
    "Goodbye",
    "it renders into the outlet"
  );
});
