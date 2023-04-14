import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse-common/utils/decorators";
import ItsATrap from "@discourse/itsatrap";
import {
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";

export default Controller.extend(ModalFunctionality, {
  showDeleteButton: false,
  prefilledDateTime: null,
  timeShortcuts: null,
  _itsatrap: null,

  onShow() {
    const currentStatus = { ...this.model.status };
    this.setProperties({
      status: currentStatus,
      hidePauseNotifications: this.model.hidePauseNotifications,
      pauseNotifications: this.model.pauseNotifications,
      showDeleteButton: !!this.model.status,
      timeShortcuts: this._buildTimeShortcuts(),
      prefilledDateTime: currentStatus?.ends_at,
    });

    this.set("_itsatrap", new ItsATrap());
  },

  onClose() {
    this._itsatrap.destroy();
    this.set("_itsatrap", null);
    this.set("timeShortcuts", null);
  },

  @discourseComputed("status.emoji", "status.description")
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
    Promise.resolve(this.model.deleteAction())
      .then(() => this.send("closeModal"))
      .catch((e) => this._handleError(e));
  },

  @action
  onTimeSelected(_, time) {
    this.set("status.endsAt", time);
  },

  @action
  saveAndClose() {
    const newStatus = {
      description: this.status.description,
      emoji: this.status.emoji,
      ends_at: this.status.endsAt?.toISOString(),
    };

    Promise.resolve(this.model.saveAction(newStatus, this.pauseNotifications))
      .then(() => this.send("closeModal"))
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
    const timezone = this.currentUser.user_option.timezone;
    const shortcuts = timeShortcuts(timezone);
    return [shortcuts.oneHour(), shortcuts.twoHours(), shortcuts.tomorrow()];
  },
});
