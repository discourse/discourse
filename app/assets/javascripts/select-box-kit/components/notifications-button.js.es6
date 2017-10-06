import DropdownSelectBoxComponent from "select-box-kit/components/dropdown-select-box";
import { iconHTML } from "discourse-common/lib/icon-library";
import computed from "ember-addons/ember-computed-decorators";
import { buttonDetails } from "discourse/lib/notification-levels";
import { allLevels } from "discourse/lib/notification-levels";

export default DropdownSelectBoxComponent.extend({
  classNames: "notifications-button",
  i18nPrefix: "",
  i18nPostfix: "",
  nameProperty: "key",
  showFullTitle: true,
  fullWidthOnMobile: true,
  content: allLevels,
  collectionHeight: "auto",
  value: Em.computed.alias("notificationLevel"),

  @computed("selectedDetails")
  headerIcon(details) {
    return iconHTML(details.icon, {class: details.key}).htmlSafe();
  },

  @computed("selectedDetails.key", "i18nPrefix")
  selectedTitle(key, prefix) {
    return I18n.t(`${prefix}.${key}.title`);
  },

  @computed("value")
  selectedDetails(value) {
    return buttonDetails(value);
  },

  @computed("selectedTitle", "showFullTitle")
  headerText(selectedTitle, showFullTitle) {
    return showFullTitle ? selectedTitle : null;
  },

  @computed
  titleForRow: function() {
    return (rowComponent) => {
      const notificationLevel = rowComponent.get("content.value");
      const details = buttonDetails(notificationLevel);
      return I18n.t(`${this.get("i18nPrefix")}.${details.key}.title`);
    };
  },

  @computed
  templateForRow() {
    return (rowComponent) => {
      const content = rowComponent.get("content");
      const name = Ember.get(content, "name");
      const start = `${this.get("i18nPrefix")}.${name}${this.get("i18nPostfix")}`;
      const title = Handlebars.escapeExpression(I18n.t(`${start}.title`));
      const description = Handlebars.escapeExpression(I18n.t(`${start}.description`));
      const icon = Ember.get(content, "originalContent.icon");

      return `
        <div class="icons">
          <span class="selection-indicator"></span>
          ${iconHTML(icon, { class: name.dasherize() })}
        </div>
        <div class="texts">
          <span class="title">${title}</span>
          <span class="desc">${description}</span>
        </div>
      `;
    };
  }
});
