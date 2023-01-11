import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | site-setting", function (hooks) {
  setupRenderingTest(hooks);

  test("displays host-list setting value", async function (assert) {
    this.set("setting", {
      setting: "blocked_onebox_domains",
      value: "a.com|b.com",
      type: "host_list",
    });

    await render(hbs`<SiteSetting @setting={{this.setting}} />`);

    assert.strictEqual(query(".formatted-selection").innerText, "a.com, b.com");
  });
});
