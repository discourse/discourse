import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import I18n from "I18n";

module("Integration | Component | hidden-details", function (hooks) {
  setupRenderingTest(hooks);

  test("Shows a link and turns link into details on click", async function (assert) {
    this.set("label", "label");
    this.set("details", "details");

    await render(
      hbs`<HiddenDetails @label={{this.label}} @details={{this.details}} />`
    );

    assert.ok(exists(".btn-link"));
    assert.strictEqual(query(".btn-link span").innerText, I18n.t("label"));
    assert.notOk(exists(".description"));

    await click(".btn-link");

    assert.notOk(exists(".btn-link"));
    assert.ok(exists(".description"));
    assert.strictEqual(query(".description").innerText, "details");
  });
});
