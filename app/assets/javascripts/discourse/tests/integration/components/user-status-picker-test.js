import { module, test } from "qunit";
import { click, fillIn, render } from "@ember/test-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { hbs } from "ember-cli-htmlbars";
import { query } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | user-status-picker", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders current status", async function (assert) {
    const status = {
      emoji: "tooth",
      description: "off to dentist",
    };
    this.set("status", status);
    await render(hbs`<UserStatusPicker @status={{this.status}} />`);
    assert.equal(
      query(".emoji").alt,
      status.emoji,
      "the status emoji is shown"
    );
    assert.equal(
      query(".user-status-description").value,
      status.description,
      "the status description is shown"
    );
  });

  test("it focuses the input on insert", async function (assert) {
    await render(hbs`<UserStatusPicker />`);

    assert.dom(".user-status-description").isFocused();
  });

  test("it picks emoji", async function (assert) {
    const status = {
      emoji: "tooth",
      description: "off to dentist",
    };
    this.set("status", status);
    await render(hbs`<UserStatusPicker @status={{this.status}} />`);

    const newEmoji = "mega";
    await click(".btn-emoji");
    await fillIn(".emoji-picker-content .filter", newEmoji);
    await click(".results .emoji");

    assert.equal(query(".emoji").alt, newEmoji);
  });

  test("it sets default emoji when user starts typing a description", async function (assert) {
    const defaultEmoji = "speech_balloon";

    this.set("status", null);
    await render(hbs`<UserStatusPicker @status={{this.status}} />`);
    await fillIn(".user-status-description", "s");

    assert.equal(query(".emoji").alt, defaultEmoji);
  });
});
