import {
  acceptance,
  count,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import { registerTemporaryModule } from "../helpers/temporary-module-helper";

const HELLO =
  "discourse/plugins/my-plugin/templates/connectors/user-profile-primary/hello";
const GOODBYE =
  "discourse/plugins/my-plugin/templates/connectors/user-profile-primary/goodbye";

acceptance("Plugin Outlet - Multi Template", function (needs) {
  needs.hooks.beforeEach(() => {
    registerTemporaryModule(HELLO, hbs`<span class='hello-span'>Hello</span>`);
    registerTemporaryModule(
      GOODBYE,
      hbs`<span class='bye-span'>Goodbye</span>`
    );
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
