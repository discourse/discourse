import { tracked } from "@glimmer/tracking";
import { click, fillIn, render, rerender } from "@ember/test-helpers";
import { module, test } from "qunit";
import FlagActionType from "discourse/components/flag-action-type";
import FlagSelection from "discourse/components/flag-selection";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const NOTIFY_USER = {
  name_key: "notify_user",
  name: "Send @%{username} a message",
  description: "Talk to them",
  require_message: true,
};
const ILLEGAL = {
  name_key: "illegal",
  name: "It's illegal",
  description: "Breaks the law",
  require_message: true,
  isIllegal: true,
};

module("Integration | Component | FlagActionType", function (hooks) {
  setupRenderingTest(hooks);

  test("checks the radio of the selected flag", async function (assert) {
    const flags = [NOTIFY_USER, ILLEGAL];
    const selected = tracked(ILLEGAL);
    const select = (flag) => (selected.value = flag);

    await render(
      <template>
        <FlagSelection @flags={{flags}} as |flag|>
          <FlagActionType
            @changePostActionType={{select}}
            @flag={{flag}}
            @selectedFlag={{selected.value}}
            @username="eviltrout"
          />
        </FlagSelection>
      </template>
    );

    assert.dom("#radio_illegal").isChecked();
    assert.dom("#radio_notify_user").isNotChecked();

    selected.value = NOTIFY_USER;
    await rerender();

    assert.dom("#radio_notify_user").isChecked("follows the selected flag");
    assert.dom("#radio_illegal").isNotChecked();
  });

  test("reports the message and the confirmation", async function (assert) {
    const message = tracked("");
    const confirmed = tracked(false);
    const changeMessage = (value) => (message.value = value);
    const changeConfirmed = (value) => (confirmed.value = value);

    await render(
      <template>
        <FlagActionType
          @flag={{ILLEGAL}}
          @isConfirmed={{confirmed.value}}
          @message={{message.value}}
          @onChangeConfirmed={{changeConfirmed}}
          @onChangeMessage={{changeMessage}}
          @selectedFlag={{ILLEGAL}}
        />
      </template>
    );

    await fillIn(".flag-message", "a reason");
    assert.strictEqual(message.value, "a reason", "reports the message");

    await click(".flag-confirmation input");
    assert.true(confirmed.value, "reports the confirmation");
    assert.dom(".flag-confirmation input").isChecked();
  });
});
