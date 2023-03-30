import { module, test } from "qunit";
import { render, triggerEvent } from "@ember/test-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { hbs } from "ember-cli-htmlbars";
import { exists, fakeTime, query } from "discourse/tests/helpers/qunit-helpers";

async function mouseenter() {
  await triggerEvent(query(".user-status-message"), "mouseenter");
}

async function mouseleave() {
  await triggerEvent(query(".user-status-message"), "mouseleave");
}

module("Integration | Component | user-status-message", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.currentUser.user_option.timezone = "UTC";
  });

  hooks.afterEach(function () {
    if (this.clock) {
      this.clock.restore();
    }
  });

  test("it renders user status emoji", async function (assert) {
    this.set("status", { emoji: "tooth", description: "off to dentist" });
    await render(hbs`<UserStatusMessage @status={{this.status}} />`);
    assert.ok(exists("img.emoji[alt='tooth']"), "the status emoji is shown");
  });

  test("it doesn't render status description by default", async function (assert) {
    this.set("status", { emoji: "tooth", description: "off to dentist" });
    await render(hbs`<UserStatusMessage @status={{this.status}} />`);
    assert.notOk(exists(".user-status-message-description"));
  });

  test("it renders status description if enabled", async function (assert) {
    this.set("status", { emoji: "tooth", description: "off to dentist" });
    await render(hbs`
      <UserStatusMessage
       @status={{this.status}}
       @showDescription=true/>
    `);
    assert.equal(
      query(".user-status-message-description").innerText.trim(),
      "off to dentist"
    );
  });

  test("it shows the until TIME on the tooltip if status will expire today", async function (assert) {
    this.clock = fakeTime(
      "2100-02-01T08:00:00.000Z",
      this.currentUser.user_option.timezone,
      true
    );
    this.set("status", {
      emoji: "tooth",
      description: "off to dentist",
      ends_at: "2100-02-01T12:30:00.000Z",
    });

    await render(hbs`<UserStatusMessage @status={{this.status}} />`);

    await mouseenter();
    assert.equal(
      document
        .querySelector("[data-tippy-root] .user-status-tooltip-until")
        .textContent.trim(),
      "Until: 12:30 PM"
    );
  });

  test("it shows the until DATE on the tooltip if status will expire tomorrow", async function (assert) {
    this.clock = fakeTime(
      "2100-02-01T08:00:00.000Z",
      this.currentUser.user_option.timezone,
      true
    );
    this.set("status", {
      emoji: "tooth",
      description: "off to dentist",
      ends_at: "2100-02-02T12:30:00.000Z",
    });

    await render(hbs`<UserStatusMessage @status={{this.status}} />`);

    await mouseenter();
    assert.equal(
      document
        .querySelector("[data-tippy-root] .user-status-tooltip-until")
        .textContent.trim(),
      "Until: Feb 2"
    );
  });

  test("it doesn't show until datetime on the tooltip if status doesn't have expiration date", async function (assert) {
    this.clock = fakeTime(
      "2100-02-01T08:00:00.000Z",
      this.currentUser.user_option.timezone,
      true
    );
    this.set("status", {
      emoji: "tooth",
      description: "off to dentist",
      ends_at: null,
    });

    await render(hbs`<UserStatusMessage @status={{this.status}} />`);

    await mouseenter();
    assert.notOk(
      document.querySelector("[data-tippy-root] .user-status-tooltip-until")
    );
  });

  test("it shows tooltip by default", async function (assert) {
    this.set("status", {
      emoji: "tooth",
      description: "off to dentist",
    });

    await render(hbs`<UserStatusMessage @status={{this.status}} />`);
    await mouseenter();

    assert.ok(
      document.querySelector("[data-tippy-root] .user-status-message-tooltip")
    );
  });

  test("it accepts optional onTrigger and onUntrigger callbacks", async function (assert) {
    this.set("status", {
      emoji: "tooth",
      description: "off to dentist",
    });

    this.set("active", false);
    this.set("onTrigger", () => this.set("active", true));
    this.set("onUntrigger", () => this.set("active", false));

    await render(
      hbs`<UserStatusMessage @status={{this.status}} @onTrigger={{this.onTrigger}} @onUntrigger={{this.onUntrigger}}/>`
    );

    await mouseenter();
    assert.strictEqual(this.active, true);

    await mouseleave();
    assert.strictEqual(this.active, false);
  });

  test("it doesn't show tooltip if disabled", async function (assert) {
    this.set("status", {
      emoji: "tooth",
      description: "off to dentist",
    });

    await render(
      hbs`<UserStatusMessage @status={{this.status}} @showTooltip={{false}} />`
    );
    await mouseenter();

    assert.notOk(
      document.querySelector("[data-tippy-root] .user-status-message-tooltip")
    );
  });

  test("doesn't blow up with an anonymous user", async function (assert) {
    this.owner.unregister("service:current-user");
    this.set("status", {
      emoji: "tooth",
      description: "off to dentist",
      ends_at: "2100-02-02T12:30:00.000Z",
    });

    await render(hbs`<UserStatusMessage @status={{this.status}} />`);

    assert.dom(".user-status-message").exists();
  });
});
