import {
  acceptance,
  count,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import Ember from "ember";

const HELLO = "javascripts/multi-test/connectors/user-profile-primary/hello";
const GOODBYE =
  "javascripts/multi-test/connectors/user-profile-primary/goodbye";

acceptance("Plugin Outlet - Multi Template", function (needs) {
  needs.hooks.beforeEach(() => {
    Ember.TEMPLATES[HELLO] = hbs`<span class='hello-span'>Hello</span>`;
    Ember.TEMPLATES[GOODBYE] = hbs`<span class='bye-span'>Goodbye</span>`;
  });

  needs.hooks.afterEach(() => {
    delete Ember.TEMPLATES[HELLO];
    delete Ember.TEMPLATES[GOODBYE];
  });

  test("Renders a template into the outlet", async function (assert) {
    await visit("/u/eviltrout");
    assert.strictEqual(
      count(".user-profile-primary-outlet.hello"),
      1,
      "it has class names"
    );
    assert.strictEqual(
      count(".user-profile-primary-outlet.goodbye"),
      1,
      "it has class names"
    );
    assert.strictEqual(
      query(".hello-span").innerText,
      "Hello",
      "it renders into the outlet"
    );
    assert.strictEqual(
      query(".bye-span").innerText,
      "Goodbye",
      "it renders into the outlet"
    );
  });
});
