import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse-common/utils/decorators";
import { later } from "@ember/runloop";
import { makeArray } from "discourse-common/lib/helpers";
import { Promise } from "rsvp";
import { isTesting } from "discourse-common/config/environment";
import { action } from "@ember/object";
import Service, { inject as service } from "@ember/service";

const TRANSITION_TIME = isTesting() ? 0 : 125; // CSS transition time
const DEFAULT_VISIBLE_SECTIONS = ["favorites", "smileys_&_emotion"];
const DEFAULT_LAST_SECTION = "favorites";

export default class ChatEmojiPickerManager extends Service {
  @service appEvents;

  @tracked closing = false;
  @tracked loading = false;
  @tracked picker = null;
  @tracked emojis = null;
  @tracked visibleSections = DEFAULT_VISIBLE_SECTIONS;
  @tracked lastVisibleSection = DEFAULT_LAST_SECTION;
  @tracked element = null;

  get sections() {
    return !this.loading && this.emojis ? Object.keys(this.emojis) : [];
  }

  @bind
  closeExisting() {
    this.visibleSections = DEFAULT_VISIBLE_SECTIONS;
    this.lastVisibleSection = DEFAULT_LAST_SECTION;
    this.picker = null;
  }

  @bind
  close() {
    this.closing = true;

    later(() => {
      if (this.isDestroyed || this.isDestroying) {
        return;
      }

      this.visibleSections = DEFAULT_VISIBLE_SECTIONS;
      this.lastVisibleSection = DEFAULT_LAST_SECTION;
      this.closing = false;
      this.picker = null;
    }, TRANSITION_TIME);
  }

  addVisibleSections(sections) {
    this.visibleSections = makeArray(this.visibleSections)
      .concat(makeArray(sections))
      .uniq();
  }

  open(picker) {
    if (this.picker) {
      if (this.picker.trigger === picker?.trigger) {
        this.closeExisting();
      } else {
        this.closeExisting();
        this.picker = picker;
      }
    } else {
      this.picker = picker;
    }
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
