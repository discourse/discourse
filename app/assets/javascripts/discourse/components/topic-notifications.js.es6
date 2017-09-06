import DropdownSelectBoxComponent from "discourse/components/dropdown-select-box";
import { observes, on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import { topicLevels, buttonDetails } from 'discourse/lib/notification-levels';
import { iconHTML } from 'discourse-common/lib/icon-library';

export default DropdownSelectBoxComponent.extend({
  classNames: ["topic-notifications"],

  content: topicLevels,

  i18nPrefix: 'category.notifications',
  i18nPostfix: '',

  textKey: "key",
  showFullTitle: true,
  fullWidthOnMobile: true,

  minWidth: "auto",

  @on("init")
  _setInitialNotificationLevel() {
    this.set("value", this.get("topic.details.notification_level"));
  },

  @on("didInsertElement")
  _bindGlobalLevelChanged() {
    this.appEvents.on("topic-notifications-button:changed", (msg) => {
      if (msg.type === "notification") {
        this.set("value", msg.id);
      }
    });
  },

  @on("willDestroyElement")
  _unbindGlobalLevelChanged() {
    this.appEvents.off("topic-notifications-button:changed");
  },

  @observes("value")
  _notificationLevelChanged() {
    this.get("topic.details").updateNotifications(this.get("value"));
    this.appEvents.trigger('topic-notifications-button:changed', {type: 'notification', id: this.get("value")});
  },

  @computed("topic.details.notification_level")
  icon(notificationLevel) {
    const details = buttonDetails(notificationLevel);
    return iconHTML(details.icon, {class: details.key}).htmlSafe();
  },

  @computed("topic.details.notification_level", "showFullTitle")
  generatedHeadertext(notificationLevel, showFullTitle) {
    if (showFullTitle) {
      const details = buttonDetails(notificationLevel);
      return I18n.t(`topic.notifications.${details.key}.title`);
    } else {
      return null;
    }
  },

  templateForRow: function() {
    return (rowComponent) => {
      const content = rowComponent.get("content");
      const start = `${this.get('i18nPrefix')}.${content.key}${this.get('i18nPostfix')}`;
      const title = I18n.t(`${start}.title`);
      const description = I18n.t(`${start}.description`);

      return `
        <div class="icons">
          <span class="selection-indicator"></span>
          ${iconHTML(content.icon, { class: content.key })}
        </div>
        <div class="texts">
          <span class="title">${title}</span>
          <span class="desc">${description}</span>
        </div>
      `;
    };
  }.property(),
});
