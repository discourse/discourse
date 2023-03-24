import { withPluginApi } from "discourse/lib/plugin-api";
import {
  addChatMessageDecorator,
  resetChatMessageDecorators,
} from "discourse/plugins/chat/discourse/components/chat-message";
import { registerChatComposerButton } from "discourse/plugins/chat/discourse/lib/chat-composer-buttons";
import { addChatDrawerStateCallback } from "discourse/plugins/chat/discourse/services/chat-state-manager";

/**
 * Class exposing the javascript API available to plugins and themes.
 * @class PluginApi
 */

/**
 * Callback used to decorate a chat message
 *
 * @callback PluginApi~decorateChatMessageCallback
 * @param {ChatMessage} chatMessage - model
 * @param {HTMLElement} messageContainer - DOM node
 * @param {ChatChannel} chatChannel - model
 */

/**
 * Callback used to decorate a chat message
 *
 * @callback PluginApi~chatDrawerStateCallbak
 * @param {Object} state
 * @param {boolean} state.isDrawerActive - is the chat drawer active
 * @param {boolean} state.isDrawerExpanded - is the chat drawer expanded
 */

/**
 * Decorate a chat message
 *
 * @memberof PluginApi
 * @instance
 * @function decorateChatMessage
 * @param {PluginApi~decorateChatMessageCallback} decorator
 * @example
 *
 * api.decorateChatMessage((chatMessage, messageContainer) => {
 *   messageContainer.dataset.foo = chatMessage.id;
 * });
 */

/**
 * Register a button in the chat composer
 *
 * @memberof PluginApi
 * @instance
 * @function registerChatComposerButton
 * @param {Object} options
 * @param {number} options.id - The id of the button
 * @param {function} options.action - An action name or an anonymous function called when the button is pressed, eg: "onFooClicked" or `() => { console.log("clicked") }`
 * @param {string} options.icon - A valid font awesome icon name, eg: "far fa-image"
 * @param {string} options.label - Text displayed on the button, a translatable key, eg: "foo.bar"
 * @param {string} options.translatedLabel - Text displayed on the button, a string, eg: "Add gifs"
 * @param {string} [options.position] - Can be "inline" or "dropdown", defaults to "inline"
 * @param {string} [options.title] - Title attribute of the button, a translatable key, eg: "foo.bar"
 * @param {string} [options.translatedTitle] - Title attribute of the button, a string, eg: "Add gifs"
 * @param {string} [options.ariaLabel] - aria-label attribute of the button, a translatable key, eg: "foo.bar"
 * @param {string} [options.translatedAriaLabel] - aria-label attribute of the button, a string, eg: "Add gifs"
 * @param {string} [options.classNames] - Additional names to add to the button’s class attribute, eg: ["foo", "bar"]
 * @param {boolean} [options.displayed] - Hide or show the button
 * @param {boolean} [options.disabled] - Sets the disabled attribute on the button
 * @param {number} [options.priority] - An integer defining the order of the buttons, higher comes first, eg: `700`
 * @param {Array.<string>} [options.dependentKeys] - List of property names which should trigger a refresh of the buttons when changed, eg: `["foo.bar", "bar.baz"]`
 * @example
 *
 * api.registerChatComposerButton({
 *   id: "foo",
 *   displayed() {
 *     return this.site.mobileView && this.canAttachUploads;
 *   }
 * });
 */

/**
 * Callback when the sate of the chat drawer changes
 *
 * @memberof PluginApi
 * @instance
 * @function addChatDrawerStateCallback
 * @param {PluginApi~chatDrawerStateCallbak} callback
 * @example
 *
 * api.addChatDrawerStateCallback(({isDrawerExpanded, isDrawerActive}) => {
 *   if (isDrawerActive && isDrawerExpanded) {
 *     // do something
 *   }
 * });
 */

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

      if (!apiPrototype.hasOwnProperty("addChatDrawerStateCallback")) {
        Object.defineProperty(apiPrototype, "addChatDrawerStateCallback", {
          value(callback) {
            addChatDrawerStateCallback(callback);
          },
        });
      }
    });
  },

  teardown() {
    resetChatMessageDecorators();
  },
};
