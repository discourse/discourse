import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChatNavbarToggleDrawerButton from "discourse/plugins/chat/discourse/components/chat/navbar/toggle-drawer-button";

module("Component | ChatNavbar | ToggleDrawerButton", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.chatStateManager = getOwner(this).lookup("service:chat-state-manager");
  });

  test("shows a collapse button when the drawer is expanded", async function (assert) {
    this.chatStateManager.didExpandDrawer();

    await render(<template><ChatNavbarToggleDrawerButton /></template>);

    assert
      .dom(".c-navbar__toggle-drawer-button")
      .exists("the collapse button is shown")
      .hasAttribute("title", i18n("chat.collapse"));
    assert.dom(".c-navbar__toggle-drawer-button .d-icon-minus").exists();
  });

  test("shows an expand button when the drawer is collapsed", async function (assert) {
    this.chatStateManager.didCollapseDrawer();

    await render(<template><ChatNavbarToggleDrawerButton /></template>);

    assert
      .dom(".c-navbar__toggle-drawer-button")
      .exists("the expand button is shown")
      .hasAttribute("title", i18n("chat.expand"));
    assert.dom(".c-navbar__toggle-drawer-button .d-icon-angles-up").exists();
  });

  test("expands the drawer when clicked", async function (assert) {
    this.chatStateManager.didCollapseDrawer();

    await render(<template><ChatNavbarToggleDrawerButton /></template>);
    await click(".c-navbar__toggle-drawer-button");

    assert.true(
      this.chatStateManager.isDrawerExpanded,
      "the drawer is expanded"
    );
  });

  test("collapses the drawer when clicked", async function (assert) {
    this.chatStateManager.didExpandDrawer();

    await render(<template><ChatNavbarToggleDrawerButton /></template>);
    await click(".c-navbar__toggle-drawer-button");

    assert.false(
      this.chatStateManager.isDrawerExpanded,
      "the drawer is collapsed"
    );
  });
});
