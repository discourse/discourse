import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | time-gap", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders days correctly", async function (assert) {
    this.set("daysSince", 5);
    await render(hbs`<TimeGap @daysSince={{this.daysSince}} />`);
    assert
      .dom(".small-action-desc.timegap")
      .hasText(i18n("dates.later.x_days", { count: 5 }));
  });

  test("it renders months correctly", async function (assert) {
    this.set("daysSince", 90);
    await render(hbs`<TimeGap @daysSince={{this.daysSince}} />`);
    assert
      .dom(".small-action-desc.timegap")
      .hasText(i18n("dates.later.x_months", { count: 3 }));
  });

  test("it renders years correctly", async function (assert) {
    this.set("daysSince", 730);
    await render(hbs`<TimeGap @daysSince={{this.daysSince}} />`);
    assert
      .dom(".small-action-desc.timegap")
      .hasText(i18n("dates.later.x_years", { count: 2 }));
  });

  test("it renders the correct elements", async function (assert) {
    this.set("daysSince", 10);
    await render(hbs`<TimeGap @daysSince={{this.daysSince}} />`);
    assert.dom(".topic-avatar").exists();
    assert.dom(".small-action-desc.timegap").exists();
  });
});
