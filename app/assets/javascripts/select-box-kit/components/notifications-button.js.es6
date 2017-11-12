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
  headerComponent: "notifications-button/notifications-button-header",

  i18nPrefix: "",
  i18nPostfix: "",
  showFullTitle: true,

  loadValueFunction() {
    return this.get("notificationLevel");
  },

  computeHeaderContent() {
    let content = this.baseHeaderComputedContent();

    content.name = I18n.t(`${this.get("i18nPrefix")}.${this.get("selectedDetails.key")}.title`);

    content.icons = [
      iconHTML(this.get("selectedDetails.icon"), {
        class: this.get("selectedDetails.key")
      }).htmlSafe()
    ];
    content.hasSelection = this.get("selectedComputedContent").length >= 1;

    return content;
  },

  @on("didReceiveAttrs", "didUpdateAttrs")
  _setComponentOptions() {
    this.get("headerComponentOptions").setProperties({
      showFullTitle: this.get("showFullTitle")
    });
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
