import Component from "@ember/component";
import { propertyEqual } from "discourse/lib/computed";

export default Component.extend({
  tagName: "li",
  classNames: ["modal-tab"],
  panel: null,
  selectedPanel: null,
  panelsLength: null,
  classNameBindings: ["isActive", "singleTab", "panel.id"],
  singleTab: Ember.computed.equal("panelsLength", 1),
  title: Ember.computed.alias("panel.title"),
  isActive: propertyEqual("panel.id", "selectedPanel.id"),

  click() {
    this.onSelectPanel(this.panel);
  }
});
