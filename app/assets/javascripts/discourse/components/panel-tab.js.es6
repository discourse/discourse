import { propertyEqual } from "discourse/lib/computed";

export default Ember.Component.extend({
  tagName: "li",
  classNames: ["panel-tab"],
  panel: null,
  selectedPanel: null,
  panelsLength: null,
  classNameBindings: ["isActive", "isSingleTab"],
  isSingleTab: Ember.computed.equal("panelsLength", 1),
  title: Ember.computed.alias("panel.title"),
  isActive: propertyEqual("panel.id", "selectedPanel.id"),

  click() {
    this.onSelectPanel(this.get("panel"));
  }
});
