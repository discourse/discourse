import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  publishToMessageBus,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

async function openUserStatusModal() {
  await click(".header-dropdown-toggle.current-user button");
  await click("#user-menu-button-profile");
  await click(".set-user-status button");
}

async function pickEmoji(emoji) {
  await click(".btn-emoji");
  await fillIn(".emoji-picker-content .filter", emoji);
  await click(".results .emoji");
}

async function setDoNotDisturbMode() {
  await click(".pause-notifications input[type=checkbox]");
}

acceptance("User Status", function (needs) {
  const userStatus = "off to dentist";
  const userStatusEmoji = "tooth";
  const userId = 1;
  const userTimezone = "UTC";

  needs.user({ id: userId, "user_option.timezone": userTimezone });

  needs.pretender((server, helper) => {
    server.put("/user-status.json", () => {
      publishToMessageBus(`/user-status/${userId}`, {
        description: userStatus,
        emoji: userStatusEmoji,
      });
      return helper.response({ success: true });
    });
    server.delete("/user-status.json", () => {
      publishToMessageBus(`/user-status/${userId}`, null);
      return helper.response({ success: true });
    });
    server.delete("/do-not-disturb.json", () =>
      helper.response({ success: true })
    );
  });

  test("shows user status on loaded page", async function (assert) {
    this.siteSettings.enable_user_status = true;
    updateCurrentUser({
      status: { description: userStatus, emoji: userStatusEmoji },
    });

    await visit("/");
    await click(".header-dropdown-toggle.current-user button");
    await click("#user-menu-button-profile");

    assert.equal(
      query(
        "div.quick-access-panel li.set-user-status span.item-label"
      ).textContent.trim(),
      userStatus,
      "shows user status description on the menu"
    );

    assert.equal(
      query("div.quick-access-panel li.set-user-status img.emoji").alt,
      `${userStatusEmoji}`,
      "shows user status emoji on the menu"
    );

    assert.equal(
      query(".header-dropdown-toggle .user-status-background img.emoji").alt,
      `:${userStatusEmoji}:`,
      "shows user status emoji on the user avatar in the header"
    );
  });

  test("shows user status on the user status modal", async function (assert) {
    this.siteSettings.enable_user_status = true;

    updateCurrentUser({
      status: {
        description: userStatus,
        emoji: userStatusEmoji,
        ends_at: "2100-02-01T09:35:00.000Z",
      },
    });

    await visit("/");
    await openUserStatusModal();

    assert.equal(
      query(`.btn-emoji img.emoji`).title,
      userStatusEmoji,
      "status emoji is shown"
    );
    assert.equal(
      query(".user-status-description").value,
      userStatus,
      "status description is shown"
    );
    assert.equal(
      query(".date-picker").value,
      "2100-02-01",
      "date of auto removing of status is shown"
    );
    assert.equal(
      query(".time-input").value,
      "09:35",
      "time of auto removing of status is shown"
    );
  });

  test("emoji picking", async function (assert) {
    this.siteSettings.enable_user_status = true;

    await visit("/");
    await openUserStatusModal();

    assert.dom(".d-icon-discourse-emojis").exists("empty status icon is shown");

    await click(".btn-emoji");
    assert.dom(".emoji-picker.opened").exists("emoji picker is opened");

    await fillIn(".emoji-picker-content .filter", userStatusEmoji);
    await click(".results .emoji");
    assert
      .dom(`.btn-emoji img.emoji[title=${userStatusEmoji}]`)
      .exists("chosen status emoji is shown");
  });

  test("setting user status", async function (assert) {
    this.siteSettings.enable_user_status = true;

    await visit("/");
    await openUserStatusModal();

    await fillIn(".user-status-description", userStatus);
    await pickEmoji(userStatusEmoji);
    assert
      .dom(`.btn-emoji img.emoji[title=${userStatusEmoji}]`)
      .exists("chosen status emoji is shown");
    await click(".btn-primary"); // save

    assert.equal(
      query(".header-dropdown-toggle .user-status-background img.emoji").alt,
      `:${userStatusEmoji}:`,
      "shows user status emoji on the user avatar in the header"
    );

    await click(".header-dropdown-toggle.current-user button");
    await click("#user-menu-button-profile");
    assert.equal(
      query(
        "div.quick-access-panel li.set-user-status span.item-label"
      ).textContent.trim(),
      userStatus,
      "shows user status description on the menu"
    );

    assert.equal(
      query("div.quick-access-panel li.set-user-status img.emoji").alt,
      `${userStatusEmoji}`,
      "shows user status emoji on the menu"
    );
  });

  test("updating user status", async function (assert) {
    this.siteSettings.enable_user_status = true;
    updateCurrentUser({ status: { description: userStatus } });
    const updatedStatus = "off to dentist the second time";

    await visit("/");
    await openUserStatusModal();

    await fillIn(".user-status-description", updatedStatus);
    await pickEmoji(userStatusEmoji);
    await click(".btn-primary"); // save

    await click(".header-dropdown-toggle.current-user button");
    await click("#user-menu-button-profile");
    assert.equal(
      query(
        "div.quick-access-panel li.set-user-status span.item-label"
      ).textContent.trim(),
      updatedStatus,
      "shows user status description on the menu"
    );
    assert.equal(
      query("div.quick-access-panel li.set-user-status img.emoji").alt,
      `${userStatusEmoji}`,
      "shows user status emoji on the menu"
    );
  });

  test("clearing user status", async function (assert) {
    this.siteSettings.enable_user_status = true;
    updateCurrentUser({ status: { description: userStatus } });

    await visit("/");
    await openUserStatusModal();
    await click(".btn.delete-status");

    assert
      .dom(".header-dropdown-toggle .user-status-background")
      .doesNotExist();
  });

  test("setting user status with auto removing timer", async function (assert) {
    this.siteSettings.enable_user_status = true;

    await visit("/");
    await openUserStatusModal();

    await fillIn(".user-status-description", "off to <img src=''> dentist");
    await pickEmoji(userStatusEmoji);
    await click("#tap_tile_one_hour");
    await click(".btn-primary"); // save

    assert
      .dom(".user-status-background img")
      .hasAttribute(
        "title",
        /^off to <img src=''> dentist/,
        "title is properly escaped"
      );

    await click(".header-dropdown-toggle.current-user button");
    await click("#user-menu-button-profile");

    assert.equal(
      query(
        "div.quick-access-panel li.set-user-status span.relative-date"
      ).textContent.trim(),
      "1h",
      "shows user status timer on the menu"
    );
  });

  test("it's impossible to set status without description", async function (assert) {
    this.siteSettings.enable_user_status = true;

    await visit("/");
    await openUserStatusModal();
    await pickEmoji(userStatusEmoji);

    assert.dom(".btn-primary").isDisabled("the save button is disabled");
  });

  test("sets default status emoji automatically after user started inputting  status description", async function (assert) {
    this.siteSettings.enable_user_status = true;
    const defaultStatusEmoji = "speech_balloon";

    await visit("/");
    await openUserStatusModal();
    await fillIn(".user-status-description", "some status");

    assert
      .dom(`.btn-emoji img.emoji[title=${defaultStatusEmoji}]`)
      .exists("default status emoji is shown");
  });

  test("shows actual status on the modal after canceling the modal and opening it again", async function (assert) {
    this.siteSettings.enable_user_status = true;

    updateCurrentUser({
      status: { description: userStatus, emoji: userStatusEmoji },
    });

    await visit("/");
    await openUserStatusModal();
    await fillIn(".user-status-description", "another status");
    await pickEmoji("cold_face"); // another emoji
    await click(".d-modal-cancel");
    await openUserStatusModal();

    assert.equal(
      query(`.btn-emoji img.emoji`).title,
      userStatusEmoji,
      "the actual status emoji is shown"
    );
    assert.equal(
      query(".user-status-description").value,
      userStatus,
      "the actual status description is shown"
    );
  });

  test("shows the trash button when editing status that was set before", async function (assert) {
    this.siteSettings.enable_user_status = true;
    updateCurrentUser({ status: { description: userStatus } });

    await visit("/");
    await openUserStatusModal();

    assert.dom(".btn.delete-status").exists();
  });

  test("doesn't show the trash button when status wasn't set before", async function (assert) {
    this.siteSettings.enable_user_status = true;
    updateCurrentUser({ status: null });

    await visit("/");
    await openUserStatusModal();

    assert.dom(".btn.delete-status").doesNotExist();
  });

  test("shows empty modal after deleting the status", async function (assert) {
    this.siteSettings.enable_user_status = true;

    updateCurrentUser({
      status: { description: userStatus, emoji: userStatusEmoji },
    });

    await visit("/");
    await openUserStatusModal();
    await click(".btn.delete-status");
    await openUserStatusModal();

    assert.dom(".d-icon-discourse-emojis").exists("empty status icon is shown");
    assert.equal(
      query(".user-status-description").value,
      "",
      "no status description is shown"
    );
  });
});

acceptance(
  "User Status - pause notifications (do not disturb mode)",
  function (needs) {
    const userStatus = "off to dentist";
    const userStatusEmoji = "tooth";
    const userId = 1;
    const userTimezone = "UTC";

    needs.user({ id: userId, "user_option.timezone": userTimezone });

    needs.pretender((server, helper) => {
      server.put("/user-status.json", () => {
        return helper.response({ success: true });
      });
      server.delete("/user-status.json", () => {
        return helper.response({ success: true });
      });
      server.post("/do-not-disturb.json", (request) => {
        const duration = request.requestBody.match(/(?<=duration=)\d+/g)[0]; // body is something like "duration=134"
        const endsAt = moment.utc().add(duration, "minutes").toISOString();
        return helper.response({ ends_at: endsAt });
      });
      server.delete("/do-not-disturb.json", () =>
        helper.response({ success: true })
      );
    });

    test("shows the pause notifications control group", async function (assert) {
      this.siteSettings.enable_user_status = true;

      await visit("/");
      await openUserStatusModal();

      assert.dom(".pause-notifications").exists();
    });

    test("sets do-not-disturb mode", async function (assert) {
      this.siteSettings.enable_user_status = true;

      await visit("/");
      await openUserStatusModal();

      await fillIn(".user-status-description", userStatus);
      await pickEmoji(userStatusEmoji);
      await click("#tap_tile_one_hour");
      await setDoNotDisturbMode();
      await click(".btn-primary"); // save

      assert
        .dom(".do-not-disturb-background .d-icon-discourse-dnd")
        .exists("the DnD mode indicator on the menu is shown");
    });

    test("sets do-not-disturb mode even if ends at time wasn't chosen", async function (assert) {
      this.siteSettings.enable_user_status = true;

      await visit("/");
      await openUserStatusModal();

      await fillIn(".user-status-description", userStatus);
      await pickEmoji(userStatusEmoji);
      await setDoNotDisturbMode();
      await click(".btn-primary"); // save

      assert
        .dom(".do-not-disturb-background .d-icon-discourse-dnd")
        .exists("the DnD mode indicator on the menu is shown");
    });

    test("unsets do-not-disturb mode when removing status", async function (assert) {
      this.siteSettings.enable_user_status = true;
      updateCurrentUser({ status: { description: userStatus } });
      updateCurrentUser({ do_not_disturb_until: "2100-01-01T08:00:00.000Z" });

      await visit("/");
      await openUserStatusModal();
      await click(".btn.delete-status");

      assert
        .dom(".do-not-disturb-background .d-icon-discourse-dnd")
        .doesNotExist("there is no DnD mode indicator on the menu");
    });

    test("unsets do-not-disturb mode when updating status", async function (assert) {
      this.siteSettings.enable_user_status = true;
      updateCurrentUser({
        status: { emoji: userStatusEmoji, description: userStatus },
      });
      updateCurrentUser({ do_not_disturb_until: "2100-01-01T08:00:00.000Z" });

      await visit("/");
      await openUserStatusModal();
      await click(".pause-notifications input[type=checkbox]");
      await click(".btn-primary"); // save

      assert
        .dom(".do-not-disturb-background .d-icon-discourse-dnd")
        .doesNotExist("there is no DnD mode indicator on the menu");
    });

    test("if user isn't in DnD mode the user status modal shows it", async function (assert) {
      this.siteSettings.enable_user_status = true;
      updateCurrentUser({ do_not_disturb_until: null });

      await visit("/");
      await openUserStatusModal();

      assert.dom(".pause-notifications input").isNotChecked();
    });

    test("if user is in DnD mode the user status modal shows it", async function (assert) {
      this.siteSettings.enable_user_status = true;
      updateCurrentUser({ do_not_disturb_until: "2100-01-01T08:00:00.000Z" });

      await visit("/");
      await openUserStatusModal();

      assert.dom(".pause-notifications input").isChecked();
    });
  }
);

acceptance("User Status - user menu", function (needs) {
  const userStatus = "off to dentist";
  const userStatusEmoji = "tooth";
  const userId = 1;
  const userTimezone = "UTC";

  needs.user({
    id: userId,
    "user_option.timezone": userTimezone,
  });

  needs.pretender((server, helper) => {
    server.put("/user-status.json", () => {
      publishToMessageBus(`/user-status/${userId}`, {
        description: userStatus,
        emoji: userStatusEmoji,
      });
      return helper.response({ success: true });
    });
    server.delete("/user-status.json", () => {
      publishToMessageBus(`/user-status/${userId}`, null);
      return helper.response({ success: true });
    });
  });

  test("doesn't show the user status button on the menu by default", async function (assert) {
    this.siteSettings.enable_user_status = false;

    await visit("/");
    await click(".header-dropdown-toggle.current-user button");
    await click("#user-menu-button-profile");

    assert.dom("li.set-user-status").doesNotExist();
  });

  test("shows the user status button on the menu when enabled in settings", async function (assert) {
    this.siteSettings.enable_user_status = true;

    await visit("/");
    await click(".header-dropdown-toggle.current-user button");
    await click("#user-menu-button-profile");

    assert.dom("li.set-user-status .btn").exists("shows the button");
    assert
      .dom("li.set-user-status svg.d-icon-circle-plus")
      .exists("shows the icon on the button");
  });

  test("shows user status on the button", async function (assert) {
    this.siteSettings.enable_user_status = true;
    updateCurrentUser({
      status: { description: userStatus, emoji: userStatusEmoji },
    });

    await visit("/");
    await click(".header-dropdown-toggle.current-user button");
    await click("#user-menu-button-profile");

    assert.equal(
      query("li.set-user-status .item-label").textContent.trim(),
      userStatus,
      "shows user status description on the menu"
    );

    assert.equal(
      query("li.set-user-status .emoji").alt,
      `${userStatusEmoji}`,
      "shows user status emoji on the menu"
    );

    assert.equal(
      query(".header-dropdown-toggle .user-status-background img.emoji").alt,
      `:${userStatusEmoji}:`,
      "shows user status emoji on the user avatar in the header"
    );
  });

  test("user menu gets closed when the user status modal is opened", async function (assert) {
    this.siteSettings.enable_user_status = true;

    await visit("/");
    await click(".header-dropdown-toggle.current-user button");
    await click("#user-menu-button-profile");
    await click(".set-user-status button");

    assert.dom(".user-menu").doesNotExist();
  });
});
