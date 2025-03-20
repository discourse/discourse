import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import FutureDateInput from "discourse/components/future-date-input";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { timeShortcuts } from "discourse/lib/time-shortcut";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";

export default class IgnoreDurationModal extends Component {
  @service currentUser;

  @tracked flash;

  @tracked loading = false;
  @tracked ignoredUntil = null;
  @tracked ignoredUsername = this.args.model.ignoredUsername;

  enableSelection = this.args.model.enableSelection ?? true;

  get timeShortcuts() {
    const timezone = this.currentUser.user_option.timezone;
    const shortcuts = timeShortcuts(timezone);
    return [
      shortcuts.laterToday(),
      shortcuts.tomorrow(),
      shortcuts.laterThisWeek(),
      shortcuts.thisWeekend(),
      shortcuts.monday(),
      shortcuts.twoWeeks(),
      shortcuts.nextMonth(),
      shortcuts.twoMonths(),
      shortcuts.threeMonths(),
      shortcuts.fourMonths(),
      shortcuts.sixMonths(),
      shortcuts.oneYear(),
      shortcuts.forever(),
    ];
  }

  @action
  ignore() {
    if (!this.ignoredUntil || !this.ignoredUsername) {
      this.flash = i18n(
        "user.user_notifications.ignore_duration_time_frame_required"
      );
      return;
    }
    this.loading = true;
    User.findByUsername(this.ignoredUsername).then((user) => {
      user
        .updateNotificationLevel({
          level: "ignore",
          expiringAt: this.ignoredUntil,
          actingUser: this.args.model.actingUser,
        })
        .then(() => {
          this.args.model.onUserIgnored?.(this.ignoredUsername);
          this.args.closeModal();
        })
        .catch(popupAjaxError)
        .finally(() => (this.loading = false));
    });
  }

  @action
  updateIgnoredUsername(selected) {
    this.ignoredUsername = selected.firstObject;
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "user.user_notifications.ignore_duration_title"}}
      @flash={{this.flash}}
      @autoFocus="false"
      class="ignore-duration-with-username-modal"
    >
      <:body>
        {{#if this.enableSelection}}
          <div class="controls tracking-controls">
            <label>{{icon "far-eye-slash" class="icon"}}
              {{i18n
                "user.user_notifications.ignore_duration_username"
              }}</label>
            <EmailGroupUserChooser
              @value={{this.ignoredUsername}}
              @onChange={{this.updateIgnoredUsername}}
              @options={{hash excludeCurrentUser=true maximum=1}}
            />
          </div>
        {{/if}}
        <FutureDateInput
          @label="user.user_notifications.ignore_duration_when"
          @input={{readonly this.ignoredUntil}}
          @customShortcuts={{this.timeShortcuts}}
          @includeDateTime={{false}}
          @onChangeInput={{fn (mut this.ignoredUntil)}}
        />
        <p>{{i18n "user.user_notifications.ignore_duration_note"}}</p>
      </:body>
      <:footer>
        <DButton
          @disabled={{this.saveDisabled}}
          @label="user.user_notifications.ignore_duration_save"
          @action={{this.ignore}}
          class="btn-primary"
        />
        <ConditionalLoadingSpinner @size="small" @condition={{this.loading}} />
      </:footer>
    </DModal>
  </template>
}
