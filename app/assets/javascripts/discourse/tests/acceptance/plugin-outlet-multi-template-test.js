import {
  acceptance,
  count,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { clearCache } from "discourse/lib/plugin-connectors";
import hbs from "htmlbars-inline-precompile";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

const HELLO = "javascripts/multi-test/connectors/user-profile-primary/hello";
const GOODBYE =
  "javascripts/multi-test/connectors/user-profile-primary/goodbye";

acceptance("Plugin Outlet - Multi Template", function (needs) {
  needs.hooks.beforeEach(() => {
    clearCache();
    Ember.TEMPLATES[HELLO] = hbs`<span class='hello-span'>Hello</span>`;
    Ember.TEMPLATES[GOODBYE] = hbs`<span class='bye-span'>Goodbye</span>`;
  });

  needs.hooks.afterEach(() => {
    delete Ember.TEMPLATES[HELLO];
    delete Ember.TEMPLATES[GOODBYE];
    clearCache();
  });

  test("Renders a template into the outlet", async function (assert) {
    await visit("/u/eviltrout");
    assert.equal(
      count(".user-profile-primary-outlet.hello"),
      1,
      "it has class names"
    );
    assert.equal(
      count(".user-profile-primary-outlet.goodbye"),
      1,
      "it has class names"
    );
    assert.equal(
      queryAll(".hello-span").text(),
      "Hello",
      "it renders into the outlet"
    );
    assert.equal(
      queryAll(".bye-span").text(),
      "Goodbye",
      "it renders into the outlet"
    );
  });
});
