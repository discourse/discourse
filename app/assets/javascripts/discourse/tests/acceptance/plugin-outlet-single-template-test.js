import {
  acceptance,
  count,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

const CONNECTOR =
  "javascripts/single-test/connectors/user-profile-primary/hello";

acceptance("Plugin Outlet - Single Template", function (needs) {
  needs.hooks.beforeEach(() => {
    // eslint-disable-next-line no-undef
    Ember.TEMPLATES[
      CONNECTOR
    ] = hbs`<span class='hello-username'>{{model.username}}</span>`;
  });

  needs.hooks.afterEach(() => {
    // eslint-disable-next-line no-undef
    delete Ember.TEMPLATES[CONNECTOR];
  });

  test("Renders a template into the outlet", async function (assert) {
    await visit("/u/eviltrout");
    assert.strictEqual(
      count(".user-profile-primary-outlet.hello"),
      1,
      "it has class names"
    );
    assert.strictEqual(
      queryAll(".hello-username").text(),
      "eviltrout",
      "it renders into the outlet"
    );
  });
});
