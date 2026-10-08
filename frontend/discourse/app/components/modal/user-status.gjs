import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import ItsATrap from "@discourse/itsatrap";
import UserStatusPicker from "discourse/components/user-status-picker";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getURLWithCDN } from "discourse/lib/get-url";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { emojiUnescape } from "discourse/lib/text";
import {
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";
import { escapeExpression } from "discourse/lib/utilities";
import User from "discourse/models/user";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import DTimeShortcutPicker from "discourse/ui-kit/d-time-shortcut-picker";
import dBoundAvatar from "discourse/ui-kit/helpers/d-bound-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

export default class UserStatusModal extends Component {
  @service currentUser;
  @service dialog;
  @service siteSettings;

  @tracked emojiChosen = false;
  @tracked loadedUser;

  status = trackedObject({
    emoji: "slightly_smiling_face",
    ...this.args.model.status,
  });
  timeShortcuts = this.#buildTimeShortcuts();
  _itsatrap = new ItsATrap();

  constructor() {
    super(...arguments);

    if (!this.args.model.user) {
      this.#loadPreviewUser();
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this._itsatrap.destroy();
  }

  get user() {
    return this.args.model.user ?? this.loadedUser ?? this.currentUser;
  }

  get cardBackgroundStyle() {
    const url = this.user.card_background_upload_url;

    if (!url || !this.siteSettings.allow_profile_backgrounds) {
      return;
    }

    return trustHTML(`background-image: url(${getURLWithCDN(url)})`);
  }

  get nameFirst() {
    return prioritizeNameInUx(this.user.name);
  }

  get statusEmoji() {
    return emojiUnescape(escapeExpression(`:${this.status.emoji}:`));
  }

  get statusEndsAt() {
    return this.status.endsAt !== undefined
      ? this.status.endsAt
      : this.status.ends_at;
  }

  get isDefaultEmoji() {
    return !this.args.model.status?.emoji && !this.emojiChosen;
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
  onEmojiSelected() {
    this.emojiChosen = true;
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
      emoji: this.isDefaultEmoji ? "speech_balloon" : this.status.emoji,
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

  async #loadPreviewUser() {
    this.loadedUser = await User.findByUsername(this.currentUser.username, {
      forCard: true,
    }).catch(() => null);
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
      class={{dConcatClass
        "modal-user-status"
        (if this.isDefaultEmoji "--default-emoji")
      }}
      @closeModal={{@closeModal}}
      @title={{i18n "user_status.set_custom_status"}}
    >
      <:body>
        <div
          aria-hidden="true"
          class="user-card --preview"
          style={{this.cardBackgroundStyle}}
        >
          <div class="card-content">
            <div class="card-row first-row">
              <div class="user-card-avatar-wrapper">
                <div class="user-card-avatar">
                  <span class="card-huge-avatar">
                    {{dBoundAvatar this.user "large"}}
                  </span>
                </div>

                {{#if this.status.description}}
                  <div class="user-status">
                    {{#unless this.isDefaultEmoji}}
                      {{trustHTML this.statusEmoji}}
                    {{/unless}}
                    <span class="user-status__description">
                      {{this.status.description}}
                    </span>
                    {{dFormatDate this.statusEndsAt format="tiny"}}
                  </div>
                {{else}}
                  <div class="user-status --empty">
                    {{#unless this.isDefaultEmoji}}
                      {{trustHTML this.statusEmoji}}
                    {{/unless}}
                    <span class="user-status__description">
                      {{i18n "user_status.what_are_you_doing"}}
                    </span>
                  </div>
                {{/if}}
              </div>
              <div class="names">
                <div class="names__primary">
                  <span class="name-username-wrapper">
                    {{if this.nameFirst this.user.name this.user.username}}
                  </span>
                </div>
                {{#if this.nameFirst}}
                  <div class="names__secondary username">
                    {{this.user.username}}
                  </div>
                {{else if this.user.name}}
                  <div class="names__secondary full-name">
                    {{this.user.name}}
                  </div>
                {{/if}}
              </div>
            </div>
          </div>
        </div>

        <div class="control-group">
          <UserStatusPicker
            @onEmojiSelected={{this.onEmojiSelected}}
            @status={{this.status}}
          />
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
