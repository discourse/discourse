import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | badge-button", function (hooks) {
  setupRenderingTest(hooks);

  test("disabled badge", async function (assert) {
    this.set("badge", { enabled: false });

    await render(hbs`<BadgeButton @badge={{this.badge}} />`);

    assert.dom(".user-badge.disabled").exists();
  });

  test("enabled badge", async function (assert) {
    this.set("badge", { enabled: true });

    await render(hbs`<BadgeButton @badge={{this.badge}} />`);

    assert.dom(".user-badge.disabled").doesNotExist();
  });

  test("data-badge-name", async function (assert) {
    this.set("badge", { name: "foo" });

    await render(hbs`<BadgeButton @badge={{this.badge}} />`);

    assert.dom('.user-badge[data-badge-name="foo"]').exists();
  });

  test("title", async function (assert) {
    this.set("badge", { description: "a <a href>good</a> run" });

    await render(hbs`<BadgeButton @badge={{this.badge}} />`);

    assert.strictEqual(
      query(".user-badge").title,
      "a good run",
      "it strips html"
    );

    this.set("badge", { description: "a bad run" });

    assert.strictEqual(
      query(".user-badge").title,
      "a bad run",
      "it updates title when changing description"
    );
  });

  test("icon", async function (assert) {
    this.set("badge", { icon: "xmark" });

    await render(hbs`<BadgeButton @badge={{this.badge}} />`);

    assert.dom(".d-icon.d-icon-xmark").exists();
  });

  test("accepts block", async function (assert) {
    this.set("badge", {});

    await render(hbs`
      <BadgeButton @badge={{this.badge}}>
        <span class="test"></span>
      </BadgeButton>
    `);

    assert.dom(".test").exists();
  });

  test("badgeTypeClassName", async function (assert) {
    this.set("badge", { badgeTypeClassName: "foo" });

    await render(hbs`<BadgeButton @badge={{this.badge}} />`);

    assert.dom(".user-badge.foo").exists();
  });

  test("showName hides the name", async function (assert) {
    this.set("badge", { name: "foo" });

    await render(
      hbs`<BadgeButton @badge={{this.badge}} @showName={{false}} />`
    );

    assert.dom(".badge-display-name").doesNotExist();
  });

  test("showName defaults to true", async function (assert) {
    this.set("badge", { name: "foo" });

    await render(hbs`<BadgeButton @badge={{this.badge}} />`);

    assert.dom(".badge-display-name").exists();
  });
});
