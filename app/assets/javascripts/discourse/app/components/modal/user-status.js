import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ItsATrap from "@discourse/itsatrap";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";

export default class UserStatusModal extends Component {
  @service currentUser;
  @service dialog;

  status = new TrackedObject({ ...this.args.model.status });
  timeShortcuts = this.#buildTimeShortcuts();
  _itsatrap = new ItsATrap();

  willDestroy() {
    super.willDestroy(...arguments);
    this._itsatrap.destroy();
  }

  get showDeleteButton() {
    return !!this.args.model.status;
  }

  get prefilledDateTime() {
    return this.status?.ends_at;
  }

  get saveDisabled() {
    return !this.status?.emoji || !this.status?.description;
  }

  get customTimeShortcutLabels() {
    return {
      [TIME_SHORTCUT_TYPES.NONE]: "time_shortcut.never",
    };
  }

  get hiddenTimeShortcutOptions() {
    return [TIME_SHORTCUT_TYPES.LAST_CUSTOM];
  }

  #buildTimeShortcuts() {
    const shortcuts = timeShortcuts(this.currentUser.user_option.timezone);
    return [shortcuts.oneHour(), shortcuts.twoHours(), shortcuts.tomorrow()];
  }

  #handleError(e) {
    if (typeof e === "string") {
      this.dialog.alert(e);
    } else {
      popupAjaxError(e);
    }
  }

  @action
  onTimeSelected(_, time) {
    this.status.endsAt = time;
  }

  @action
  async delete() {
    try {
      await this.args.model.deleteAction();
      this.args.closeModal();
    } catch (e) {
      this.#handleError(e);
    }
  }

  @action
  async saveAndClose() {
    const newStatus = {
      description: this.status.description,
      emoji: this.status.emoji,
      ends_at: this.status.endsAt?.toISOString(),
    };

    try {
      await this.args.model.saveAction(
        newStatus,
        this.args.model.pauseNotifications
      );
      this.args.closeModal();
    } catch (e) {
      this.#handleError(e);
    }
  }
}
