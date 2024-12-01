import { render, triggerEvent } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | user-status-message", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.currentUser.user_option.timezone = "UTC";
    this.status = { emoji: "tooth", description: "off to dentist" };
  });

  hooks.afterEach(function () {
    if (this.clock) {
      this.clock.restore();
    }
  });

  test("it renders user status emoji", async function (assert) {
    await render(hbs`<UserStatusMessage @status={{this.status}} />`);
    assert.dom("img.emoji[alt='tooth']").exists("the status emoji is shown");
  });

  test("it renders status description if enabled", async function (assert) {
    await render(hbs`
      <UserStatusMessage
       @status={{this.status}}
       @showDescription={{true}} />
    `);

    assert
      .dom('[data-trigger][data-identifier="user-status-message-tooltip"]')
      .containsText("off to dentist");
  });

  test("it shows the until TIME on the tooltip if status will expire today", async function (assert) {
    this.clock = fakeTime(
      "2100-02-01T08:00:00.000Z",
      this.currentUser.user_option.timezone,
      true
    );
    this.status.ends_at = "2100-02-01T12:30:00.000Z";

    await render(
      hbs`<UserStatusMessage @status={{this.status}} /><DTooltips />`
    );
    await triggerEvent(".user-status-message", "mousemove");

    assert
      .dom('[data-content][data-identifier="user-status-message-tooltip"]')
      .containsText("Until: 12:30 PM");
  });

  test("it shows the until DATE on the tooltip if status will expire tomorrow", async function (assert) {
    this.clock = fakeTime(
      "2100-02-01T08:00:00.000Z",
      this.currentUser.user_option.timezone,
      true
    );
    this.status.ends_at = "2100-02-02T12:30:00.000Z";

    await render(
      hbs`<UserStatusMessage @status={{this.status}} /><DTooltips />`
    );
    await triggerEvent(".user-status-message", "mousemove");

    assert
      .dom('[data-content][data-identifier="user-status-message-tooltip"]')
      .containsText("Until: Feb 2");
  });

  test("it doesn't show until datetime on the tooltip if status doesn't have expiration date", async function (assert) {
    this.clock = fakeTime(
      "2100-02-01T08:00:00.000Z",
      this.currentUser.user_option.timezone,
      true
    );
    this.status.ends_at = null;

    await render(
      hbs`<UserStatusMessage @status={{this.status}} /><DTooltips />`
    );
    await triggerEvent(".user-status-message", "mousemove");

    assert
      .dom(
        '[data-content][data-identifier="user-status-message-tooltip"] .user-status-tooltip-until'
      )
      .doesNotExist();
  });

  test("it shows tooltip by default", async function (assert) {
    await render(
      hbs`<UserStatusMessage @status={{this.status}} /><DTooltips />`
    );
    await triggerEvent(".user-status-message", "mousemove");

    assert
      .dom('[data-content][data-identifier="user-status-message-tooltip"]')
      .exists();
  });

  test("doesn't blow up with an anonymous user", async function (assert) {
    this.owner.unregister("service:current-user");
    this.status.ends_at = "2100-02-02T12:30:00.000Z";

    await render(hbs`<UserStatusMessage @status={{this.status}} />`);

    assert
      .dom('[data-trigger][data-identifier="user-status-message-tooltip"]')
      .exists();
  });

  test("accepts a custom css class", async function (assert) {
    this.set("status", { emoji: "tooth", description: "off to dentist" });

    await render(
      hbs`<UserStatusMessage @status={{this.status}} class="foo" />`
    );

    assert
      .dom('[data-trigger][data-identifier="user-status-message-tooltip"].foo')
      .exists();
  });
});
