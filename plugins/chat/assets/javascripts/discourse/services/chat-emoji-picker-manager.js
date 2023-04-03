import { headerOffset } from "discourse/lib/offset-calculator";
import { createPopper } from "@popperjs/core";
import Service from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse-common/utils/decorators";
import { later, schedule } from "@ember/runloop";
import { makeArray } from "discourse-common/lib/helpers";
import { Promise } from "rsvp";
import { isTesting } from "discourse-common/config/environment";
import { action } from "@ember/object";

const TRANSITION_TIME = isTesting() ? 0 : 125; // CSS transition time
const DEFAULT_VISIBLE_SECTIONS = ["favorites", "smileys_&_emotion"];
const DEFAULT_LAST_SECTION = "favorites";

export default class ChatEmojiPickerManager extends Service {
  @tracked opened = false;
  @tracked closing = false;
  @tracked loading = false;
  @tracked context = null;
  @tracked emojis = null;
  @tracked visibleSections = DEFAULT_VISIBLE_SECTIONS;
  @tracked lastVisibleSection = DEFAULT_LAST_SECTION;
  @tracked initialFilter = null;
  @tracked element = null;
  @tracked callback;

  get sections() {
    return !this.loading && this.emojis ? Object.keys(this.emojis) : [];
  }

  @bind
  closeExisting() {
    this.callback = null;
    this.initialFilter = null;
    this.visibleSections = DEFAULT_VISIBLE_SECTIONS;
    this.lastVisibleSection = DEFAULT_LAST_SECTION;
  }

  @bind
  close() {
    this.context = null;
    this.closing = true;

    later(() => {
      if (this.isDestroyed || this.isDestroying) {
        return;
      }

      this.visibleSections = DEFAULT_VISIBLE_SECTIONS;
      this.lastVisibleSection = DEFAULT_LAST_SECTION;
      this.initialFilter = null;
      this.closing = false;

      this.opened = false;
    }, TRANSITION_TIME);
  }

  addVisibleSections(sections) {
    this.visibleSections = makeArray(this.visibleSections)
      .concat(makeArray(sections))
      .uniq();
  }

  startFromMessageReactionList(message, callback, options = {}) {
    const trigger = document.querySelector(
      `.chat-message-container[data-id="${message.id}"] .chat-message-react-btn`
    );
    this.startFromMessage(message, callback, trigger, options);
  }

  startFromMessageActions(message, callback, options = {}) {
    const trigger = document.querySelector(
      `.chat-message-actions-container[data-id="${message.id}"] .chat-message-actions`
    );
    this.startFromMessage(message, callback, trigger, options);
  }

  startFromMessage(
    message,
    callback,
    trigger,
    options = { filter: null, desktop: true }
  ) {
    this.initialFilter = options.filter;
    this.context = "chat-message";
    this.message = message;
    this.open(callback);
    this._popper?.destroy();

    if (options.desktop) {
      schedule("afterRender", () => {
        this._popper = createPopper(trigger, this.element, {
          placement: "top",
          modifiers: [
            {
              name: "eventListeners",
              options: {
                scroll: false,
                resize: false,
              },
            },
            {
              name: "flip",
              options: {
                padding: { top: headerOffset() },
              },
            },
          ],
        });
      });
    }
  }

  startFromComposer(context, options = { filter: null }) {
    this.initialFilter = options.filter;
    this.context = context;
    this.open();
  }

  open() {
    if (this.opened) {
      this.closeExisting();
    }

    this.opened = true;
  }

  @action
  loadEmojis() {
    if (this.emojis) {
      return Promise.resolve();
    }

    this.loading = true;

    return ajax("/chat/emojis.json")
      .then((emojis) => {
        this.emojis = emojis;
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.loading = false;
      });
  }
}
