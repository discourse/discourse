import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import computed from "ember-addons/ember-computed-decorators";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["toolbar-popup-menu-options"],
  classNames: ["toolbar-popup-menu-options"],
  isHidden: Ember.computed.empty("computedContent"),
  showFullTitle: false,

  @computed("title")
  collectionHeader(title) {
    return `<h3>${title}</h3>`;
  },

  mutateValue(value) {
    this.sendAction("onPopupMenuAction", value);
    this.setProperties({ value: null, highlighted: null });
  },

  computeContent(content) {
    return content
      .map(contentItem => {
        if (contentItem.condition) {
          return {
            icon: contentItem.icon,
            name: I18n.t(contentItem.label),
            id: contentItem.action
          };
        }
      })
      .filter(contentItem => contentItem);
  },

  didInsertElement() {
    this._super();

    $("#reply-control").on("touchstart.toolbar-popup-menu-options", event => {
      if (this.get("isExpanded") && !this.element.contains(event.target)) {
        this.close(event);
      }
    });
  },

  willDestroyElement() {
    this._super();

    $("#reply-control").off("touchstart.toolbar-popup-menu-options");
  }
});
