import { withPluginApi } from "discourse/lib/plugin-api";
import {
  addChatMessageDecorator,
  resetChatMessageDecorators,
} from "discourse/plugins/chat/discourse/components/chat-message";
import { registerChatComposerButton } from "discourse/plugins/chat/discourse/lib/chat-composer-buttons";
import { removeChatComposerSecondaryActions } from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import {
  registerTranscriptSourceType,
  resetTranscriptSourceTypes,
} from "discourse/plugins/chat/discourse/lib/transcript-source-types";
import {
  registerChatSound,
  resetChatSounds,
  setDefaultChatSound,
} from "discourse/plugins/chat/discourse/services/chat-audio-manager";
import { addChatDrawerStateCallback } from "discourse/plugins/chat/discourse/services/chat-state-manager";

/**
 * Class exposing the javascript API available to plugins and themes.
 * @class PluginApi
 */

/**
 * Callback used to decorate a chat message
 *
 * @callback PluginApi~decorateChatMessageCallback
 * @param {HTMLElement} messageContainer - DOM node
 * @param {Object} helper - decorated HTML helper
 * @param {ChatMessage} chatMessage - model
 */

/**
 * Callback used to decorate a chat message
 *
 * @callback PluginApi~chatDrawerStateCallback
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
 * api.decorateChatMessage((messageContainer, _helper, chatMessage) => {
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
 * @param {PluginApi~chatDrawerStateCallback} callback
 * @example
 *
 * api.addChatDrawerStateCallback(({isDrawerExpanded, isDrawerActive}) => {
 *   if (isDrawerActive && isDrawerExpanded) {
 *     // do something
 *   }
 * });
 */

/**
 * Send a chat message, message or uploads must be provided
 *
 * @memberof PluginApi
 * @instance
 * @function sendChatMessage
 * @param {number} channelId - The id of the channel
 * @param {Object} options
 * @param {string} [options.message] - The content of the message to send
 * @param {string} [options.uploads] - A list of uploads to send
 * @param {number} [options.threadId] - The thread id where the message should be sent
 * @param {number} [options.inReplyToId] - The ID of the replied to  message
 *
 * @example
 *
 * api.sendChatMessage(
 *   1,
 *  { message: "Hello world", threadId: 2 }
 * );
 */

/**
 * Removes secondary actions from the chat composer
 *
 * @memberof PluginApi
 * @instance
 * @function removeChatComposerSecondaryActions
 * @param {...string} [1] - List of secondary action ids to remove, eg: `"copyLink", "select"
 * @example
 *
 * api.removeChatComposerSecondaryActions("copyLink", "select");
 */

/**
 * Registers how chat transcripts quoted in posts present a non-channel source,
 * named by the transcript's `sourceType` attribute
 *
 * @memberof PluginApi
 * @instance
 * @function registerChatTranscriptSourceType
 * @param {string} type - value of the `sourceType` attribute
 * @param {Object} options
 * @param {string} options.icon - icon shown before the source name
 * @param {string} [options.label] - translation key for the header label
 * @example
 *
 * api.registerChatTranscriptSourceType("meeting", {
 *   icon: "users",
 *   label: "my_plugin.meeting_transcript",
 * });
 */

/**
 * Registers a chat notification sound users can pick in their preferences.
 * Registering a built-in name (eg: "classic") replaces that sound.
 *
 * @memberof PluginApi
 * @instance
 * @function registerChatSound
 * @param {string} name - stored in the user's `chat_sound` option
 * @param {Object} options
 * @param {string|function} options.incoming - audio file URL, or a function receiving `(audioContext, startTime)` that schedules Web Audio nodes
 * @param {string|function} [options.mention] - played for mentions, defaults to `incoming`
 * @param {string} [options.label] - translation key for the preference option
 * @param {string} [options.translatedLabel] - preference option text
 * @example
 *
 * api.registerChatSound("ping", {
 *   incoming: settings.theme_uploads.ping,
 *   mention: settings.theme_uploads.ping_mention,
 *   label: themePrefix("chat_sounds.ping"),
 * });
 */

/**
 * Sets the sound used when a user hasn't picked one for new messages in the
 * open channel, or picked one that no longer exists. Users who haven't opted
 * into notification sounds stay silent.
 *
 * @memberof PluginApi
 * @instance
 * @function setDefaultChatSound
 * @param {string} name - a built-in or registered sound
 * @example
 *
 * api.setDefaultChatSound("ping");
 */

export default {
  name: "chat-plugin-api",
  after: "inject-discourse-objects",

  initialize() {
    withPluginApi((api) => {
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

      if (!apiPrototype.hasOwnProperty("sendChatMessage")) {
        Object.defineProperty(apiPrototype, "sendChatMessage", {
          async value(channelId, options = {}) {
            return this.container
              .lookup("service:chat-api")
              .sendMessage(channelId, {
                thread_id: options.threadId,
                in_reply_to_id: options.inReplyToId,
                post_ids: options.postIds,
                topic_id: options.topicId,
                message: options.message,
                uploads: options.uploads,
              });
          },
        });
      }

      if (!apiPrototype.hasOwnProperty("registerChatTranscriptSourceType")) {
        Object.defineProperty(
          apiPrototype,
          "registerChatTranscriptSourceType",
          {
            value(type, options) {
              registerTranscriptSourceType(type, options);
            },
          }
        );
      }

      if (!apiPrototype.hasOwnProperty("registerChatSound")) {
        Object.defineProperty(apiPrototype, "registerChatSound", {
          value(name, options) {
            registerChatSound(name, options);
          },
        });
      }

      if (!apiPrototype.hasOwnProperty("setDefaultChatSound")) {
        Object.defineProperty(apiPrototype, "setDefaultChatSound", {
          value(name) {
            setDefaultChatSound(name);
          },
        });
      }

      if (!apiPrototype.hasOwnProperty("removeChatComposerSecondaryActions")) {
        Object.defineProperty(
          apiPrototype,
          "removeChatComposerSecondaryActions",
          {
            value(...actionIds) {
              removeChatComposerSecondaryActions(actionIds);
            },
          }
        );
      }
    });
  },

  teardown() {
    resetChatMessageDecorators();
    resetTranscriptSourceTypes();
    resetChatSounds();
  },
};
