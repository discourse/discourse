import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import element from "discourse/helpers/element";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

/**
 * Toggle button for the upcoming changes debug mode in the dev-tools toolbar.
 * Shows upcoming changes and allows you to toggle them on and off. Only works
 * on the client/UI, doesn't affect server-side behaviour of having upcoming
 * changes on.
 */
export default class UpcomingChangesDebugButton extends Component {
  @service siteSettings;

  get upcomingChanges() {
    return this.siteSettings.currentUserUpcomingChanges;
  }

  @action
  toggleUpcomingChangesDebug(changeSettingName) {
    // Does the same thing as onClientSettings in SubscribeUserNotificationsInit,
    // where we respond to MessageBus client settings changes from SiteSettingExtension.
    this.siteSettings[changeSettingName] =
      !this.siteSettings[changeSettingName];
    this.siteSettings.currentUserUpcomingChanges[changeSettingName] =
      !this.siteSettings.currentUserUpcomingChanges[changeSettingName];
  }

  @bind
  isChecked(changeSettingName) {
    return this.upcomingChanges[changeSettingName];
  }

  <template>
    <DMenu
      @identifier="upcoming-changes-debug-menu"
      @triggerClass={{concatClass
        "toggle-upcoming-changes-menu"
        (if this.isActive "--active")
      }}
      @triggerComponent={{element "button"}}
      @modalForMobile={{false}}
      @title={{i18n "dev_tools.toggle_upcoming_changes_debug"}}
    >
      <:trigger>
        {{icon "flask"}}
      </:trigger>
      <:content>
        <div class="upcoming-changes-debug-menu">
          {{#each-in this.upcomingChanges as |changeSettingName|}}
            <label>
              <input
                type="checkbox"
                checked={{this.isChecked changeSettingName}}
                {{on
                  "change"
                  (fn this.toggleUpcomingChangesDebug changeSettingName)
                }}
              />
              {{changeSettingName}}
            </label>
          {{/each-in}}
        </div>
      </:content>
    </DMenu>
  </template>
}
