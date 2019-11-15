import { alias } from "@ember/object/computed";
import DropdownSelectBoxRoxComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-row";
import { buttonDetails } from "discourse/lib/notification-levels";
import discourseComputed from "discourse-common/utils/decorators";
import { iconHTML } from "discourse-common/lib/icon-library";

export default DropdownSelectBoxRoxComponent.extend({
  classNames: "notifications-button-row",

  i18nPrefix: alias("options.i18nPrefix"),
  i18nPostfix: alias("options.i18nPostfix"),

  @discourseComputed("computedContent.value", "i18nPrefix", "i18nPostfix")
  title(value, prefix, postfix) {
    const key = buttonDetails(value).key;
    return I18n.t(`${prefix}.${key}${postfix}.title`);
  },

  @discourseComputed(
    "computedContent.name",
    "computedContent.originalContent.icon"
  )
  icon(contentName, icon) {
    return iconHTML(icon, { class: contentName.dasherize() });
  },

  @discourseComputed("_start")
  description(_start) {
    if (this.site && this.site.mobileView) {
      return null;
    }

    return Handlebars.escapeExpression(I18n.t(`${_start}.description`));
  },

  @discourseComputed("_start")
  name(_start) {
    return Handlebars.escapeExpression(I18n.t(`${_start}.title`));
  },

  @discourseComputed("i18nPrefix", "i18nPostfix", "computedContent.name")
  _start(prefix, postfix, contentName) {
    return `${prefix}.${contentName}${postfix}`;
  }
});
