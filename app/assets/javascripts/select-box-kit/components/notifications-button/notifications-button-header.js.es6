import DropdownSelectBoxHeaderComponent from "select-box-kit/components/dropdown-select-box/dropdown-select-box-header";
import computed from "ember-addons/ember-computed-decorators";
import { iconHTML } from 'discourse-common/lib/icon-library';
import { buttonDetails } from "discourse/lib/notification-levels";

export default DropdownSelectBoxHeaderComponent.extend({
  classNames: "notifications-button-header",

  i18nPrefix: Ember.computed.alias("options.i18nPrefix"),
  shouldDisplaySelectedName: Ember.computed.alias("options.showFullTitle"),

  @computed("_selectedDetails.icon", "_selectedDetails.key")
  icon(icon, key) {
    return iconHTML(icon, {class: key}).htmlSafe();
  },

  @computed("_selectedDetails.key", "i18nPrefix")
  selectedName(key, prefix) {
    return I18n.t(`${prefix}.${key}.title`);
  },

  @computed("selectedContent.firstObject.value")
  _selectedDetails(value) { return buttonDetails(value); }
});
