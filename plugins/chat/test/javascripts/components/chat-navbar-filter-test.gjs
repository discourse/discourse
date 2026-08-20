import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatNavbarFilter from "discourse/plugins/chat/discourse/components/chat/navbar/filter";

module("Component | ChatNavbar | Filter", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.chatStateManager = getOwner(this).lookup("service:chat-state-manager");
  });

  test("shows the filter button", async function (assert) {
    await render(<template><ChatNavbarFilter /></template>);

    assert.dom(".c-navbar__filter").exists("the filter button is shown");
    assert.dom(".c-navbar__filter").doesNotHaveClass("active");
  });

  test("is active while filtering", async function (assert) {
    await render(
      <template><ChatNavbarFilter @isFiltering={{true}} /></template>
    );

    assert.dom(".c-navbar__filter").hasClass("active");
  });

  test("toggles the filter when clicked", async function (assert) {
    this.toggled = false;
    const onToggleFilter = () => (this.toggled = true);

    await render(
      <template>
        <ChatNavbarFilter @onToggleFilter={{onToggleFilter}} />
      </template>
    );
    await click(".c-navbar__filter");

    assert.true(this.toggled, "the filter callback is called");
  });

  test("does not show the filter button when the drawer is collapsed", async function (assert) {
    this.chatStateManager.didCollapseDrawer();

    await render(<template><ChatNavbarFilter /></template>);

    assert.dom(".c-navbar__filter").doesNotExist("the filter button is hidden");
  });

  test("shows the filter button when the drawer is expanded", async function (assert) {
    this.chatStateManager.didExpandDrawer();

    await render(<template><ChatNavbarFilter /></template>);

    assert.dom(".c-navbar__filter").exists("the filter button is shown");
  });
});
