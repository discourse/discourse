import { visit } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
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
    assert.dom(".user-profile-primary-outlet").exists({ count: 2 });
    assert.dom(".user-profile-primary-outlet.hello").exists("has class names");
    assert
      .dom(".user-profile-primary-outlet.goodbye")
      .exists("has class names");
    assert.dom(".hello-span").hasText("Hello", "renders into the outlet");
    assert.dom(".bye-span").hasText("Goodbye", "renders into the outlet");
  });
});
