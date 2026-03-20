import Component from "@glimmer/component";
import { action } from "@ember/object";
import { empty } from "@ember/object/computed";
import { trustHTML } from "@ember/template";
import { topicLevels } from "discourse/lib/notification-levels";
import DButton from "discourse/ui-kit/d-button";
import DRadioButton from "discourse/ui-kit/d-radio-button";
import { i18n } from "discourse-i18n";

// Support for changing the notification level of various topics
export default class NotificationLevel extends Component {
  notificationLevelId = null;

  @empty("notificationLevelId") disabled;

  get notificationLevels() {
    return topicLevels.map((level) => ({
      id: level.id.toString(),
      name: i18n(`topic.notifications.${level.key}.title`),
      description: i18n(`topic.notifications.${level.key}.description`),
    }));
  }

  @action
  changeNotificationLevel() {
    this.args.performAndRefresh({
      type: "change_notification_level",
      notification_level_id: this.notificationLevelId,
    });
  }

  <template>
    <div class="bulk-notification-list">
      {{#each this.notificationLevels as |level|}}
        <div class="controls">
          <label class="radio notification-level-radio checkbox-label">
            <DRadioButton
              @value={{level.id}}
              @name="notification_level"
              @selection={{this.notificationLevelId}}
            />
            <strong>{{level.name}}</strong>
            <div class="description">{{trustHTML level.description}}</div>
          </label>
        </div>
      {{/each}}
    </div>

    <DButton
      @disabled={{this.disabled}}
      @action={{this.changeNotificationLevel}}
      @label="topics.bulk.change_notification_level"
    />
  </template>
}
