import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | badge-button", function (hooks) {
  setupRenderingTest(hooks);

  test("disabled badge", async function (assert) {
    this.set("badge", { enabled: false });

    await render(hbs`<BadgeButton @badge={{this.badge}} />`);

    assert.ok(exists(".user-badge.disabled"));
  });

  test("enabled badge", async function (assert) {
    this.set("badge", { enabled: true });

    await render(hbs`<BadgeButton @badge={{this.badge}} />`);

    assert.notOk(exists(".user-badge.disabled"));
  });

  test("data-badge-name", async function (assert) {
    this.set("badge", { name: "foo" });

    await render(hbs`<BadgeButton @badge={{this.badge}} />`);

    assert.ok(exists('.user-badge[data-badge-name="foo"]'));
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
    this.set("badge", { icon: "times" });

    await render(hbs`<BadgeButton @badge={{this.badge}} />`);

    assert.ok(exists(".d-icon.d-icon-times"));
  });

  test("accepts block", async function (assert) {
    this.set("badge", {});

    await render(hbs`
      <BadgeButton @badge={{this.badge}}>
        <span class="test"></span>
      </BadgeButton>
    `);

    assert.ok(exists(".test"));
  });

  test("badgeTypeClassName", async function (assert) {
    this.set("badge", { badgeTypeClassName: "foo" });

    await render(hbs`<BadgeButton @badge={{this.badge}} />`);

    assert.ok(exists(".user-badge.foo"));
  });
});
