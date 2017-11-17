import DropdownSelectBoxComponent from "select-box-kit/components/dropdown-select-box";
import { default as computed, on } from "ember-addons/ember-computed-decorators";
import { buttonDetails } from "discourse/lib/notification-levels";
import { allLevels } from "discourse/lib/notification-levels";
import { iconHTML } from 'discourse-common/lib/icon-library';

export default DropdownSelectBoxComponent.extend({
  classNames: "notifications-button",
  nameProperty: "key",
  fullWidthOnMobile: true,
  content: allLevels,
  collectionHeight: "auto",
  castInteger: true,
  autofilterable: false,
  filterable: false,
  rowComponent: "notifications-button/notifications-button-row",

  i18nPrefix: "",
  i18nPostfix: "",

  loadValueFunction() {
    return this.get("notificationLevel");
  },

  @computed("selectedDetails.icon", "selectedDetails.key")
  iconForSelectedDetails(icon, key) {
    return iconHTML(icon, { class: key }).htmlSafe();
  },

  computeHeaderContent() {
    let content = this.baseHeaderComputedContent();
    content.name = I18n.t(`${this.get("i18nPrefix")}.${this.get("selectedDetails.key")}.title`);
    content.icons = [ this.get("iconForSelectedDetails") ];
    content.hasSelection = this.get("selectedComputedContent").length >= 1;
    return content;
  },

  @on("didReceiveAttrs")
  _setNotificationsButtonComponentOptions() {
    this.get("rowComponentOptions").setProperties({
      i18nPrefix: this.get("i18nPrefix"),
      i18nPostfix: this.get("i18nPostfix")
    });
  },

  @computed("computedValue")
  selectedDetails(computedValue) {
    return buttonDetails(computedValue);
  }
});
