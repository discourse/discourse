import { withPluginApi } from "discourse/lib/plugin-api";
import {
  addChatMessageDecorator,
  resetChatMessageDecorators,
} from "discourse/plugins/chat/discourse/components/chat-message";
import { registerChatComposerButton } from "discourse/plugins/chat/discourse/lib/chat-composer-buttons";

export default {
  name: "chat-plugin-api",
  after: "inject-discourse-objects",

  initialize() {
    withPluginApi("1.2.0", (api) => {
      const apiPrototype = Object.getPrototypeOf(api);

      if (!apiPrototype.hasOwnProperty("decorateChatMessage")) {
        Object.defineProperty(apiPrototype, "decorateChatMessage", {
          value(decorator) {
            addChatMessageDecorator(decorator);
          },
        });
      }

      if (!apiPrototype.hasOwnProperty("registerChatComposerButton")) {
        Object.defineProperty(apiPrototype, "registerChatComposerButton", {
          value(button) {
            registerChatComposerButton(button);
          },
        });
      }
    });
  },

  teardown() {
    resetChatMessageDecorators();
  },
};
