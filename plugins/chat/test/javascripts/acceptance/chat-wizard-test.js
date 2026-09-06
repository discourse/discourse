import { getOwner } from "@ember/owner";
import { settled, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  metaModifier,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Chat | Wizard", function (needs) {
  needs.user({ has_chat_enabled: true });
  needs.settings({ chat_enabled: true });
  needs.pretender((server, helper) => {
    server.get("/chat/api/me/channels", () =>
      helper.response({
        direct_message_channels: [],
        public_channels: [],
        meta: { message_bus_last_ids: {} },
        tracking: {},
      })
    );
  });

  test("chat cannot be interacted with", async function (assert) {
    await visit("/wizard");

    const chatStateManager = getOwner(this).lookup(
      "service:chat-state-manager"
    );
    chatStateManager.isDrawerActive = true;
    chatStateManager.isDrawerExpanded = true;
    await settled();

    assert
      .dom(".chat-drawer-outlet")
      .doesNotExist("an active chat drawer is not rendered");

    await triggerKeyEvent(document, "keydown", "K", metaModifier);

    assert
      .dom(".chat-modal-new-message")
      .doesNotExist("the quick channel selector cannot be opened");
  });
});
