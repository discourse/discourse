import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse-common/utils/decorators";
import ItsATrap from "@discourse/itsatrap";
import {
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";

export default Controller.extend(ModalFunctionality, {
  userStatusService: service("user-status"),

  emoji: null,
  description: null,
  endsAt: null,

  showDeleteButton: false,
  prefilledDateTime: null,
  timeShortcuts: null,
  _itsatrap: null,

  onShow() {
    const status = this.currentUser.status;
    this.setProperties({
      emoji: status?.emoji,
      description: status?.description,
      endsAt: status?.ends_at,
      showDeleteButton: !!status,
      timeShortcuts: this._buildTimeShortcuts(),
      prefilledDateTime: status?.ends_at,
    });

    this.set("_itsatrap", new ItsATrap());
  },

  onClose() {
    this._itsatrap.destroy();
    this.set("_itsatrap", null);
    this.set("timeShortcuts", null);
  },

  @discourseComputed("emoji", "description")
  statusIsSet(emoji, description) {
    return !!emoji && !!description;
  },

  @discourseComputed
  customTimeShortcutLabels() {
    const labels = {};
    labels[TIME_SHORTCUT_TYPES.NONE] = "time_shortcut.never";
    return labels;
  },

  @discourseComputed
  hiddenTimeShortcutOptions() {
    return [TIME_SHORTCUT_TYPES.LAST_CUSTOM];
  },

  @action
  delete() {
    this.userStatusService
      .clear()
      .then(() => this.send("closeModal"))
      .catch((e) => this._handleError(e));
  },

  @action
  onTimeSelected(_, time) {
    this.set("endsAt", time);
  },

  @action
  saveAndClose() {
    const status = {
      description: this.description,
      emoji: this.emoji,
      ends_at: this.endsAt?.toISOString(),
    };
    this.userStatusService
      .set(status)
      .then(() => {
        this.send("closeModal");
      })
      .catch((e) => this._handleError(e));
  },

  _handleError(e) {
    if (typeof e === "string") {
      this.dialog.alert(e);
    } else {
      popupAjaxError(e);
    }
  },

  _buildTimeShortcuts() {
    const timezone = this.currentUser.timezone;
    const shortcuts = timeShortcuts(timezone);
    return [shortcuts.oneHour(), shortcuts.twoHours(), shortcuts.tomorrow()];
  },
});
