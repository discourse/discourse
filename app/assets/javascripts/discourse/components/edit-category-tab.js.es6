import discourseComputed from "discourse-common/utils/decorators";
import { scheduleOnce } from "@ember/runloop";
import Component from "@ember/component";
import { propertyEqual } from "discourse/lib/computed";

export default Component.extend({
  tagName: "li",
  classNameBindings: ["active", "tabClassName"],

  @discourseComputed("tab")
  tabClassName(tab) {
    return "edit-category-" + tab;
  },

  active: propertyEqual("selectedTab", "tab"),

  @discourseComputed("tab")
  title(tab) {
    return I18n.t("category." + tab.replace("-", "_"));
  },

  didInsertElement() {
    this._super(...arguments);
    scheduleOnce("afterRender", this, this._addToCollection);
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
