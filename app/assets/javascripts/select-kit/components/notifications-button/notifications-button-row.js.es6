import DropdownSelectBoxRoxComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-row";
import { buttonDetails } from "discourse/lib/notification-levels";
import computed from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";

export default DropdownSelectBoxRoxComponent.extend({
  classNames: "notifications-button-row",

  i18nPrefix: Ember.computed.alias("options.i18nPrefix"),
  i18nPostfix: Ember.computed.alias("options.i18nPostfix"),

  @computed("computedContent.value", "i18nPrefix", "i18nPostfix")
  title(value, prefix, postfix) {
    const key = buttonDetails(value).key;
    return I18n.t(`${prefix}.${key}${postfix}.title`);
  },

  @computed("computedContent.name", "computedContent.originalContent.icon")
  icon(contentName, icon) {
    return iconHTML(icon, { class: contentName.dasherize() });
  },

  @computed("_start")
  description(_start) {
    return Handlebars.escapeExpression(I18n.t(`${_start}.description`));
  },

  @computed("_start")
  name(_start) {
    return Handlebars.escapeExpression(I18n.t(`${_start}.title`));
  },

  @computed("i18nPrefix", "i18nPostfix", "computedContent.name")
  _start(prefix, postfix, contentName) {
    return `${prefix}.${contentName}${postfix}`;
  }
});
