import DropdownSelectBoxComponent from "select-box-kit/components/dropdown-select-box";
import { default as computed, on } from "ember-addons/ember-computed-decorators";
import { buttonDetails } from "discourse/lib/notification-levels";
import { allLevels } from "discourse/lib/notification-levels";

export default DropdownSelectBoxComponent.extend({
  classNames: "notifications-button",
  nameProperty: "key",
  fullWidthOnMobile: true,
  content: allLevels,
  collectionHeight: "auto",
  value: Ember.computed.alias("notificationLevel"),
  castInteger: true,
  autofilterable: false,
  filterable: false,
  rowComponent: "notifications-button/notifications-button-row",
  headerComponent: "notifications-button/notifications-button-header",

  i18nPrefix: "",
  i18nPostfix: "",
  showFullTitle: true,

  @on("didReceiveAttrs", "didUpdateAttrs")
  _setComponentOptions() {
    this.set("headerComponentOptions", Ember.Object.create({
      i18nPrefix: this.get("i18nPrefix"),
      showFullTitle: this.get("showFullTitle"),
    }));

    this.set("rowComponentOptions", Ember.Object.create({
      i18nPrefix: this.get("i18nPrefix"),
      i18nPostfix: this.get("i18nPostfix")
    }));
  },

  @computed("computedValue")
  selectedDetails(computedValue) {
    return buttonDetails(computedValue);
  }
});
