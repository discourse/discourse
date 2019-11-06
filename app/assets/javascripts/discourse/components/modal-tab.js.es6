import { equal, alias } from "@ember/object/computed";
import Component from "@ember/component";
import { propertyEqual } from "discourse/lib/computed";

export default Component.extend({
  tagName: "li",
  classNames: ["modal-tab"],
  panel: null,
  selectedPanel: null,
  panelsLength: null,
  classNameBindings: ["isActive", "singleTab", "panel.id"],
  singleTab: equal("panelsLength", 1),
  title: alias("panel.title"),
  isActive: propertyEqual("panel.id", "selectedPanel.id"),

  click() {
    this.onSelectPanel(this.panel);
  }
});
