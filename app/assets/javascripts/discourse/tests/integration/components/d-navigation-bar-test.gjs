import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import NavigationBar from "discourse/components/navigation-bar";
import EmberObject from "@ember/object";

const navItems = [
  EmberObject.create({ name: "new", displayName: "New" }),
  EmberObject.create({ name: "unread", displayName: "Unread" }),
];

module("Integration | Component | d-navigation-bar", function (hooks) {
  setupRenderingTest(hooks);

  test("display navigation bar items", async function (assert) {
    await render(<template><NavigationBar @navItems={{navItems}} /></template>);

    assert.dom(".nav .nav-item_new").includesText("New");
    assert.dom(".nav .nav-item_unread").includesText("Unread");
  });

  test("display navigation bar items behind a dropdown on mobile", async function (assert) {
    this.site.mobileView = true;

    await render(<template><NavigationBar @navItems={{navItems}} /></template>);

    assert.dom(".nav .nav-item_new").doesNotExist();
    assert.dom(".nav .nav-item_unread").doesNotExist();

    await click(".list-control-toggle-link-trigger");

    assert.dom(".nav .nav-item_new").includesText("New");
    assert.dom(".nav .nav-item_unread").includesText("Unread");
  });
});
