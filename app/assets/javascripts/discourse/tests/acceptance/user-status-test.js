import {
  acceptance,
  exists,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("User Status", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.put("/user-status.json", () => helper.response({ success: true }));
    server.delete("/user-status.json", () =>
      helper.response({ success: true })
    );
  });

  const userStatusFallbackEmoji = "mega";
  const userStatus = "off to dentist";

  test("doesn't show the user status button on the menu by default", async function (assert) {
    this.siteSettings.enable_user_status = false;

    await visit("/");
    await click(".header-dropdown-toggle.current-user");
    await click(".menu-links-row .user-preferences-link");

    assert.notOk(exists("div.quick-access-panel li.user-status"));
  });

  test("shows the user status button on the menu when disabled in settings", async function (assert) {
    this.siteSettings.enable_user_status = true;

    await visit("/");
    await click(".header-dropdown-toggle.current-user");
    await click(".menu-links-row .user-preferences-link");

    assert.ok(
      exists("div.quick-access-panel li.user-status"),
      "shows the button"
    );
    assert.ok(
      exists("div.quick-access-panel li.user-status svg.d-icon-plus-circle"),
      "shows the icon on the button"
    );
  });

  test("shows user status on loaded page", async function (assert) {
    this.siteSettings.enable_user_status = true;
    updateCurrentUser({ status: { description: userStatus } });

    await visit("/");
    await click(".header-dropdown-toggle.current-user");
    await click(".menu-links-row .user-preferences-link");

    assert.equal(
      query("div.quick-access-panel li.user-status span.d-button-label")
        .innerText,
      userStatus,
      "shows user status description on the menu"
    );

    assert.equal(
      query("div.quick-access-panel li.user-status img.emoji").alt,
      `:${userStatusFallbackEmoji}:`,
      "shows user status emoji on the menu"
    );

    assert.equal(
      query(".header-dropdown-toggle .user-status-background img.emoji").alt,
      `:${userStatusFallbackEmoji}:`,
      "shows user status emoji on the user avatar in the header"
    );
  });

  test("setting user status", async function (assert) {
    this.siteSettings.enable_user_status = true;

    await visit("/");
    await click(".header-dropdown-toggle.current-user");
    await click(".menu-links-row .user-preferences-link");
    await click(".user-status button");
    await fillIn(".user-status-description", userStatus);
    await click(".btn-primary");

    assert.equal(
      query(".header-dropdown-toggle .user-status-background img.emoji").alt,
      `:${userStatusFallbackEmoji}:`,
      "shows user status emoji on the user avatar in the header"
    );

    await click(".header-dropdown-toggle.current-user");
    await click(".menu-links-row .user-preferences-link");
    assert.equal(
      query("div.quick-access-panel li.user-status span.d-button-label")
        .innerText,
      userStatus,
      "shows user status description on the menu"
    );

    assert.equal(
      query("div.quick-access-panel li.user-status img.emoji").alt,
      `:${userStatusFallbackEmoji}:`,
      "shows user status emoji on the menu"
    );
  });

  test("updating user status", async function (assert) {
    this.siteSettings.enable_user_status = true;
    updateCurrentUser({ status: { description: userStatus } });
    const updatedStatus = "off to dentist the second time";

    await visit("/");
    await click(".header-dropdown-toggle.current-user");
    await click(".menu-links-row .user-preferences-link");
    await click(".user-status button");
    await fillIn(".user-status-description", updatedStatus);
    await click(".btn-primary");

    await click(".header-dropdown-toggle.current-user");
    await click(".menu-links-row .user-preferences-link");
    assert.equal(
      query("div.quick-access-panel li.user-status span.d-button-label")
        .innerText,
      updatedStatus,
      "shows user status description on the menu"
    );
  });

  test("clearing user status", async function (assert) {
    this.siteSettings.enable_user_status = true;
    updateCurrentUser({ status: { description: userStatus } });

    await visit("/");
    await click(".header-dropdown-toggle.current-user");
    await click(".menu-links-row .user-preferences-link");
    await click(".user-status button");
    await click(".btn.delete-status");

    assert.notOk(exists(".header-dropdown-toggle .user-status-background"));
  });

  test("shows the trash button when editing status that was set before", async function (assert) {
    this.siteSettings.enable_user_status = true;
    updateCurrentUser({ status: { description: userStatus } });

    await visit("/");
    await click(".header-dropdown-toggle.current-user");
    await click(".menu-links-row .user-preferences-link");
    await click(".user-status button");

    assert.ok(exists(".btn.delete-status"));
  });

  test("doesn't show the trash button when status wasn't set before", async function (assert) {
    this.siteSettings.enable_user_status = true;
    updateCurrentUser({ status: null });

    await visit("/");
    await click(".header-dropdown-toggle.current-user");
    await click(".menu-links-row .user-preferences-link");
    await click(".user-status button");

    assert.notOk(exists(".btn.delete-status"));
  });
});
