import { visit } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { registerTemporaryModule } from "discourse/tests/helpers/temporary-module-helper";

acceptance("Hbr Plugin Outlet", function (needs) {
  needs.hooks.beforeEach(function () {
    registerTemporaryModule(
      "discourse/theme-12/templates/connectors/topic-list-before-link/hello",
      hbs`<span class="lala">{{@outletArgs.topic.id}}</span>`
    );
  });

  test("renders ember plugin outlets in hbr contexts", async function (assert) {
    await visit("/");
    assert.dom(".lala").exists("renders the outlet");
    assert.dom(".lala").hasText("11557", "has the topic id");
  });
});
