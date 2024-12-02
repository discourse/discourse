import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ItsATrap from "@discourse/itsatrap";
import { TrackedObject } from "tracked-built-ins";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import TimeShortcutPicker from "discourse/components/time-shortcut-picker";
import UserStatusPicker from "discourse/components/user-status-picker";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";
import { i18n } from "discourse-i18n";

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

  <template>
    <DModal
      @title={{i18n "user_status.set_custom_status"}}
      @closeModal={{@closeModal}}
      class="user-status"
    >
      <:body>
        <div class="control-group">
          <UserStatusPicker @status={{this.status}} />
        </div>

        {{#unless @model.hidePauseNotifications}}
          <div class="control-group pause-notifications">
            <label class="checkbox-label">
              <Input @type="checkbox" @checked={{@model.pauseNotifications}} />
              {{i18n "user_status.pause_notifications"}}
            </label>
          </div>
        {{/unless}}

        <div class="control-group control-group-remove-status">
          <label class="control-label">
            {{i18n "user_status.remove_status"}}
          </label>

          <TimeShortcutPicker
            @timeShortcuts={{this.timeShortcuts}}
            @hiddenOptions={{this.hiddenTimeShortcutOptions}}
            @customLabels={{this.customTimeShortcutLabels}}
            @prefilledDatetime={{this.prefilledDateTime}}
            @onTimeSelected={{this.onTimeSelected}}
            @_itsatrap={{this._itsatrap}}
          />
        </div>
      </:body>

      <:footer>
        <DButton
          @label="user_status.save"
          @disabled={{this.saveDisabled}}
          @action={{this.saveAndClose}}
          class="btn-primary"
        />

        <DModalCancel @close={{@closeModal}} />

        {{#if this.showDeleteButton}}
          <DButton
            @icon="trash-can"
            @action={{this.delete}}
            class="delete-status btn-danger"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
