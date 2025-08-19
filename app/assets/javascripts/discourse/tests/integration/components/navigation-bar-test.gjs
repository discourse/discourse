import EmberObject from "@ember/object";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import NavigationBar from "discourse/components/navigation-bar";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const navItems = [
  EmberObject.create({ name: "new", displayName: "New" }),
  EmberObject.create({
    name: "unread",
    displayName: "Unread",
    href: "/unread",
  }),
  EmberObject.create({
    name: "votes",
    displayName: "Votes",
    href: "/latest?order=votes",
  }),
  EmberObject.create({
    name: "my-votes",
    displayName: "My votes",
    href: "/latest?state=my_votes",
  }),
];

module("Integration | Component | navigation-bar", function (hooks) {
  setupRenderingTest(hooks);

  test("display navigation bar items", async function (assert) {
    await render(<template><NavigationBar @navItems={{navItems}} /></template>);

    assert.dom(".nav .nav-item_new").includesText("New");
    assert.dom(".nav .nav-item_unread").includesText("Unread");
  });

  test("display currect url", async function (assert) {
    await render(<template><NavigationBar @navItems={{navItems}} /></template>);

    assert.dom(".nav .nav-item_new > a").hasNoAttribute("href");
    assert.dom(".nav .nav-item_unread > a").hasAttribute("href", "/unread");
    assert
      .dom(".nav .nav-item_votes > a")
      .hasAttribute("href", "/latest?order=votes");
    assert
      .dom(".nav .nav-item_my-votes > a")
      .hasAttribute("href", "/latest?state=my_votes");
  });

  test("display currect url when desktop_category_page_style is categories_and_latest_topics_created_date", async function (assert) {
    this.siteSettings.desktop_category_page_style =
      "categories_and_latest_topics_created_date";

    await render(<template><NavigationBar @navItems={{navItems}} /></template>);

    assert.dom(".nav .nav-item_new > a").hasNoAttribute("href");
    assert
      .dom(".nav .nav-item_unread > a")
      .hasAttribute("href", "/unread?order=created");
    assert
      .dom(".nav .nav-item_votes > a")
      .hasAttribute("href", "/latest?order=votes");
    assert
      .dom(".nav .nav-item_my-votes > a")
      .hasAttribute("href", "/latest?state=my_votes&order=created");
  });

  test("display navigation bar items behind a dropdown on mobile", async function (assert) {
    forceMobile();

    await render(<template><NavigationBar @navItems={{navItems}} /></template>);

    assert.dom(".nav .nav-item_new").doesNotExist();
    assert.dom(".nav .nav-item_unread").doesNotExist();

    await click(".list-control-toggle-link-trigger");

    assert.dom(".nav .nav-item_new").includesText("New");
    assert.dom(".nav .nav-item_unread").includesText("Unread");
  });
});
