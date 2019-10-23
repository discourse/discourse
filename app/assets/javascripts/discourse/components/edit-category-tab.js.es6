import Component from "@ember/component";
import { propertyEqual } from "discourse/lib/computed";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  tagName: "li",
  classNameBindings: ["active", "tabClassName"],

  @computed("tab")
  tabClassName(tab) {
    return "edit-category-" + tab;
  },

  active: propertyEqual("selectedTab", "tab"),

  @computed("tab")
  title(tab) {
    return I18n.t("category." + tab.replace("-", "_"));
  },

  didInsertElement() {
    this._super(...arguments);
    Ember.run.scheduleOnce("afterRender", this, this._addToCollection);
  },

  _addToCollection: function() {
    this.panels.addObject(this.tabClassName);
  },

  _resetModalScrollState() {
    const $modalBody = $(this.element)
      .parents("#discourse-modal")
      .find(".modal-body");
    if ($modalBody.length === 1) {
      $modalBody.scrollTop(0);
    }
  },

  actions: {
    select: function() {
      this.set("selectedTab", this.tab);
      this._resetModalScrollState();
    }
  }
});
