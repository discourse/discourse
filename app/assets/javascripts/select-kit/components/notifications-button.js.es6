import { alias } from "@ember/object/computed";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import discourseComputed, {
  observes,
  on
} from "discourse-common/utils/decorators";
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

  @discourseComputed("iconForSelectedDetails")
  headerIcon(iconForSelectedDetails) {
    return iconForSelectedDetails;
  },

  @on("init")
  @observes("i18nPostfix")
  _setNotificationsButtonComponentOptions() {
    this.rowComponentOptions.setProperties({
      i18nPrefix: this.i18nPrefix,
      i18nPostfix: this.i18nPostfix
    });
  },

  iconForSelectedDetails: alias("selectedDetails.icon"),

  computeHeaderContent() {
    let content = this._super(...arguments);
    content.name = I18n.t(
      `${this.i18nPrefix}.${this.get("selectedDetails.key")}${this.get(
        "i18nPostfix"
      )}.title`
    );
    content.hasSelection = this.hasSelection;
    return content;
  },

  @discourseComputed("computedValue")
  selectedDetails(computedValue) {
    return buttonDetails(computedValue);
  }
});
