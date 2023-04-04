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
  @tracked opened = false;
  @tracked closing = false;
  @tracked loading = false;
  @tracked picker = null;
  @tracked emojis = null;
  @tracked visibleSections = DEFAULT_VISIBLE_SECTIONS;
  @tracked lastVisibleSection = DEFAULT_LAST_SECTION;
  @tracked initialFilter = null;
  @tracked element = null;
  @tracked callback;

  @service appEvents;

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
    this.picker = null;
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

  open(picker) {
    if (this.opened) {
      this.closeExisting();
    }

    this.appEvents.trigger("d-popover:close");
    this.picker = picker;
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
