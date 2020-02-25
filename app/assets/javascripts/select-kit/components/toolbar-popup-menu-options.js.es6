import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

const HEADING_COLLECTION = "HEADING_COLLECTION";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["toolbar-popup-menu-options"],
  classNames: ["toolbar-popup-menu-options"],

  init() {
    this._super(...arguments);

    this.prependCollection(HEADING_COLLECTION);
  },

  selectKitOptions: {
    showFullTitle: false,
    filterable: false,
    autoFilterable: false
  },

  modifyContentForCollection(collection) {
    if (collection === HEADING_COLLECTION) {
      return { title: this.selectKit.options.popupTitle };
    }
  },

  modifyComponentForCollection(collection) {
    if (collection === HEADING_COLLECTION) {
      return "toolbar-popup-menu-options/toolbar-popup-menu-options-heading";
    }
  },

  modifyContent(contents) {
    return contents
      .map(content => {
        if (content.condition) {
          return {
            icon: content.icon,
            name: I18n.t(content.label),
            id: content.action
          };
        }
      })
      .filter(Boolean);
  }
});
