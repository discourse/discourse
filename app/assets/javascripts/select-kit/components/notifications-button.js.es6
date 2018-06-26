import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import {
  default as computed,
  on
} from "ember-addons/ember-computed-decorators";
import { buttonDetails } from "discourse/lib/notification-levels";
import { allLevels } from "discourse/lib/notification-levels";

export default DropdownSelectBoxComponent.extend({
  classNames: "notifications-button",
  nameProperty: "key",
  fullWidthOnMobile: true,
  content: allLevels,
  castInteger: true,
  autofilterable: false,
  filterable: false,
  rowComponent: "notifications-button/notifications-button-row",
  allowInitialValueMutation: false,
  i18nPrefix: "",
  i18nPostfix: "",

  @computed("iconForSelectedDetails")
  headerIcon(iconForSelectedDetails) {
    return iconForSelectedDetails;
  },

  iconForSelectedDetails: Ember.computed.alias("selectedDetails.icon"),

  computeHeaderContent() {
    let content = this._super();
    content.name = I18n.t(
      `${this.get("i18nPrefix")}.${this.get("selectedDetails.key")}${this.get(
        "i18nPostfix"
      )}.title`
    );
    content.hasSelection = this.get("hasSelection");
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
