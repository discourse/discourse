import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import { service } from "@ember/service";
import ItsATrap from "@discourse/itsatrap";
import UserStatusPicker from "discourse/components/user-status-picker";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import DTimeShortcutPicker from "discourse/ui-kit/d-time-shortcut-picker";
import { i18n } from "discourse-i18n";

export default class UserStatusModal extends Component {
  @service currentUser;
  @service dialog;

  status = trackedObject({ ...this.args.model.status });
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

  <template>
    <DModal
      class="user-status"
      @closeModal={{@closeModal}}
      @title={{i18n "user_status.set_custom_status"}}
    >
      <:body>
        <div class="control-group">
          <UserStatusPicker @status={{this.status}} />
        </div>

        {{#unless @model.hidePauseNotifications}}
          <div class="control-group pause-notifications">
            <label class="checkbox-label">
              <Input @checked={{@model.pauseNotifications}} @type="checkbox" />
              {{i18n "user_status.pause_notifications"}}
            </label>
          </div>
        {{/unless}}

        <div class="control-group control-group-remove-status">
          <label class="control-label">
            {{i18n "user_status.remove_status"}}
          </label>

          <DTimeShortcutPicker
            @_itsatrap={{this._itsatrap}}
            @customLabels={{this.customTimeShortcutLabels}}
            @hiddenOptions={{this.hiddenTimeShortcutOptions}}
            @onTimeSelected={{this.onTimeSelected}}
            @prefilledDatetime={{this.prefilledDateTime}}
            @timeShortcuts={{this.timeShortcuts}}
          />
        </div>
      </:body>

      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.saveAndClose}}
          @disabled={{this.saveDisabled}}
          @label="user_status.save"
        />

        <DModalCancel @close={{@closeModal}} />

        {{#if this.showDeleteButton}}
          <DButton
            class="delete-status btn-danger"
            @action={{this.delete}}
            @icon="trash-can"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
