import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default class NotificationLevelWhenAssigned extends Component {
  @service siteSettings;

  constructor(owner, args) {
    super(...arguments);
    if (this.siteSettings.assign_enabled) {
      args.outletArgs.customAttrNames.push("notification_level_when_assigned");
    }
  }

  get notificationLevelsWhenAssigned() {
    // The order matches the "notification level when replying" user preference
    return [
      {
        name: i18n("user.notification_level_when_assigned.watch_topic"),
        value: "watch_topic",
      },
      {
        name: i18n("user.notification_level_when_assigned.track_topic"),
        value: "track_topic",
      },
      {
        name: i18n("user.notification_level_when_assigned.do_nothing"),
        value: "do_nothing",
      },
    ];
  }

  <template>
    {{#if this.siteSettings.assign_enabled}}
      <div
        class="controls controls-dropdown"
        data-setting-name="user-notification-level-when-assigned"
      >
        <label>{{i18n "user.notification_level_when_assigned.label"}}</label>
        <ComboBox
          @content={{this.notificationLevelsWhenAssigned}}
          @value={{@outletArgs.model.user_option.notification_level_when_assigned}}
          @valueProperty="value"
          {{! template-lint-disable no-action }}
          @onChange={{action
            (mut @outletArgs.model.user_option.notification_level_when_assigned)
          }}
        />
      </div>
    {{/if}}
  </template>
}
