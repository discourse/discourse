import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const CONNECTOR =
  "javascripts/single-test/connectors/user-profile-primary/hello";

acceptance("Plugin Outlet - Single Template", function (needs) {
  needs.hooks.beforeEach(() => {
    Ember.TEMPLATES[CONNECTOR] = Ember.HTMLBars.compile(
      `<span class='hello-username'>{{model.username}}</span>`
    );
  });

  needs.hooks.afterEach(() => {
    delete Ember.TEMPLATES[CONNECTOR];
  });

  test("Renders a template into the outlet", async (assert) => {
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
});
