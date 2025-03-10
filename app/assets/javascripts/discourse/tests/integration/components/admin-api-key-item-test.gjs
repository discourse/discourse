import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ApiKeyItem from "admin/components/api-key-item";

module("Integration | Component | ApiKeyItem", function (hooks) {
  setupRenderingTest(hooks);

  test("global scope mode", async function (assert) {
    const apiKey = {
      scope_mode: "global",
    };

    await render(<template><ApiKeyItem @apiKey={{apiKey}} /></template>);

    assert.dom(".key-scope > .d-icon-globe").exists();
    assert.dom(".key-scope").includesText("Global");
  });

  test("read-only scope mode", async function (assert) {
    const apiKey = {
      scope_mode: "read_only",
    };

    await render(<template><ApiKeyItem @apiKey={{apiKey}} /></template>);

    assert.dom(".key-scope > .d-icon-eye").exists();
    assert.dom(".key-scope").includesText("Read-only");
  });

  test("granular scope mode", async function (assert) {
    const apiKey = {
      scope_mode: "granular",
    };

    await render(<template><ApiKeyItem @apiKey={{apiKey}} /></template>);

    assert.dom(".key-scope > .d-icon-bullseye").exists();
    assert.dom(".key-scope").includesText("Granular");
  });
});
