import Component from "@ember/component";
import { equal } from "@ember/object/computed";
import { propertyEqual } from "discourse/lib/computed";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default Component.extend({
  tagName: "li",
  classNames: ["modal-tab"],
  panel: null,
  selectedPanel: null,
  panelsLength: null,
  classNameBindings: ["isActive", "singleTab", "panel.id"],
  singleTab: equal("panelsLength", 1),
  isActive: propertyEqual("panel.id", "selectedPanel.id"),

  @discourseComputed("panel.title", "panel.rawTitle")
  title(title, rawTitle) {
    return title ? I18n.t(title) : rawTitle;
  },

  click() {
    this.set("selectedPanel", this.panel);

    if (this.onSelectPanel) {
      this.onSelectPanel(this.panel);
    }
  },
});
