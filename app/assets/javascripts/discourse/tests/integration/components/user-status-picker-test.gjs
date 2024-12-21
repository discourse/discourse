import { click, fillIn, render } from "@ember/test-helpers";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { module, test } from "qunit";
import UserStatusPicker from "discourse/components/user-status-picker";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | user-status-picker", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders current status", async function (assert) {
    const status = new TrackedObject({
      emoji: "tooth",
      description: "off to dentist",
    });

    await render(<template><UserStatusPicker @status={{status}} /></template>);

    assert
      .dom(".emoji")
      .hasAttribute("alt", status.emoji, "the status emoji is shown");
    assert
      .dom(".user-status-description")
      .hasValue(status.description, "the status description is shown");
  });

  test("it focuses the input on insert", async function (assert) {
    const status = new TrackedObject({});
    await render(<template><UserStatusPicker @status={{status}} /></template>);

    assert.dom(".user-status-description").isFocused();
  });

  test("it picks emoji", async function (assert) {
    const status = new TrackedObject({
      emoji: "tooth",
      description: "off to dentist",
    });

    await render(<template><UserStatusPicker @status={{status}} /></template>);

    await click(".btn-emoji");
    await fillIn(".emoji-picker-content .filter-input", "raised");
    await click(".emoji-picker__sections .emoji");

    assert.dom(".emoji").hasAttribute("alt", "raised_hands");
    assert.strictEqual(status.emoji, "raised_hands");
  });

  test("it sets default emoji when user starts typing a description", async function (assert) {
    const status = new TrackedObject({});

    await render(<template><UserStatusPicker @status={{status}} /></template>);

    await fillIn(".user-status-description", "s");
    assert.dom(".emoji").hasAttribute("alt", "speech_balloon");
    assert.strictEqual(status.emoji, "speech_balloon");
  });
});
