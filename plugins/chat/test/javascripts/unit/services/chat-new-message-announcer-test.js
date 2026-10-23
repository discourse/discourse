import { getOwner } from "@ember/owner";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  claimChatAlert,
  confirmChatAlert,
  resetChatAlerts,
} from "discourse/plugins/chat/discourse/lib/chat-alert-dedup";

module("Unit | Service | chat-new-message-announcer", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    resetChatAlerts();
    this.currentUser.user_option.chat_new_message_sound = true;

    const chatAudioManager = getOwner(this).lookup(
      "service:chat-audio-manager"
    );
    this.play = sinon.stub(chatAudioManager, "play").resolves(true);

    this.subject = getOwner(this).lookup("service:chat-new-message-announcer");
  });

  test("plays a sound for a new message in the active channel", function (assert) {
    this.subject.notify({ id: 1, user: {} }, { active: true });

    assert.true(this.play.calledOnce);
  });

  test("skips a message that already played as a background alert", function (assert) {
    confirmChatAlert(2);

    this.subject.notify({ id: 2, user: {} }, { active: true });

    assert.true(this.play.notCalled);
  });

  test("plays a message that another tab claimed without playing", function (assert) {
    claimChatAlert(3);

    this.subject.notify({ id: 3, user: {} }, { active: true });

    assert.true(this.play.calledOnce);
  });
});
