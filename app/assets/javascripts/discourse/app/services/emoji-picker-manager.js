import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { later } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isTesting } from "discourse-common/config/environment";
import { makeArray } from "discourse-common/lib/helpers";
import { bind } from "discourse-common/utils/decorators";

const TRANSITION_TIME = isTesting() ? 0 : 125; // CSS transition time
const DEFAULT_VISIBLE_SECTIONS = ["favorites", "smileys_&_emotion"];
const DEFAULT_LAST_SECTION = "favorites";

export default class EmojiPickerManager extends Service {
  @service appEvents;

  @tracked closing = false;
  @tracked loading = false;
  @tracked picker = null;

  @tracked element = null;

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

  open(picker) {
    if (this.picker) {
      if (this.picker.trigger === picker.trigger) {
        this.closeExisting();
      } else {
        this.closeExisting();
        this.picker = picker;
      }
    } else {
      this.picker = picker;
    }
  }
}
