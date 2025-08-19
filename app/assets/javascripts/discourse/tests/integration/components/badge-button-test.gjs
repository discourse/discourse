import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BadgeButton from "discourse/components/badge-button";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | badge-button", function (hooks) {
  setupRenderingTest(hooks);

  test("disabled badge", async function (assert) {
    const badge = { enabled: false };

    await render(<template><BadgeButton @badge={{badge}} /></template>);

    assert.dom(".user-badge.disabled").exists();
  });

  test("enabled badge", async function (assert) {
    const badge = { enabled: true };

    await render(<template><BadgeButton @badge={{badge}} /></template>);

    assert.dom(".user-badge.disabled").doesNotExist();
  });

  test("data-badge-name", async function (assert) {
    const badge = { name: "foo" };

    await render(<template><BadgeButton @badge={{badge}} /></template>);

    assert.dom('.user-badge[data-badge-name="foo"]').exists();
  });

  test("title", async function (assert) {
    const self = this;

    this.set("badge", { description: "a <a href>good</a> run" });

    await render(<template><BadgeButton @badge={{self.badge}} /></template>);

    assert
      .dom(".user-badge")
      .hasAttribute("title", "a good run", "strips html");

    this.set("badge", { description: "a bad run" });

    assert
      .dom(".user-badge")
      .hasAttribute(
        "title",
        "a bad run",
        "updates title when changing description"
      );
  });

  test("icon", async function (assert) {
    const badge = { icon: "xmark" };

    await render(<template><BadgeButton @badge={{badge}} /></template>);

    assert.dom(".d-icon.d-icon-xmark").exists();
  });

  test("accepts block", async function (assert) {
    const badge = {};

    await render(
      <template>
        <BadgeButton @badge={{badge}}>
          <span class="test"></span>
        </BadgeButton>
      </template>
    );

    assert.dom(".test").exists();
  });

  test("badgeTypeClassName", async function (assert) {
    const badge = { badgeTypeClassName: "foo" };

    await render(<template><BadgeButton @badge={{badge}} /></template>);

    assert.dom(".user-badge.foo").exists();
  });

  test("setting showName to false hides the name", async function (assert) {
    const badge = { name: "foo" };

    await render(
      <template><BadgeButton @badge={{badge}} @showName={{false}} /></template>
    );

    assert.dom(".badge-display-name").doesNotExist();
  });

  test("showName defaults to true", async function (assert) {
    const badge = { name: "foo" };

    await render(<template><BadgeButton @badge={{badge}} /></template>);

    assert.dom(".badge-display-name").exists();
  });
});
