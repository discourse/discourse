import { module, test } from "qunit";
import {
  chatComposerButtons,
  chatComposerButtonsDependentKeys,
  clearChatComposerButtons,
  registerChatComposerButton,
} from "discourse/plugins/chat/discourse/lib/chat-composer-buttons";

module("Discourse Chat | Unit | chat-composer-buttons", function (hooks) {
  hooks.beforeEach(function () {
    registerChatComposerButton({
      id: "foo",
      icon: "xmark",
      dependentKeys: ["test"],
    });

    registerChatComposerButton({
      id: "bar",
      translatedLabel() {
        return this.baz;
      },
    });
  });

  hooks.afterEach(function () {
    clearChatComposerButtons();
  });

  test("chatComposerButtons", function (assert) {
    const button = chatComposerButtons({ baz: "fooz" }, "inline")[1];
    assert.strictEqual(button.id, "bar");
    assert.strictEqual(button.label, "fooz");
  });

  test("chatComposerButtonsDependentKeys", function (assert) {
    assert.deepEqual(chatComposerButtonsDependentKeys(), ["test"]);
  });
});
