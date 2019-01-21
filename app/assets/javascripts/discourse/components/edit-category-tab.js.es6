import { propertyEqual } from "discourse/lib/computed";

export default Ember.Component.extend({
  tagName: "li",
  classNameBindings: ["active", "tabClassName"],

  tabClassName: function() {
    return "edit-category-" + this.get("tab");
  }.property("tab"),

  active: propertyEqual("selectedTab", "tab"),

  title: function() {
    return I18n.t("category." + this.get("tab").replace("-", "_"));
  }.property("tab"),

  didInsertElement() {
    this._super(...arguments);
    Ember.run.scheduleOnce("afterRender", this, this._addToCollection);
  },

  _addToCollection: function() {
    this.get("panels").addObject(this.get("tabClassName"));
  },

  _resetModalScrollState() {
    const $modalBody = this.$()
      .parents("#discourse-modal")
      .find(".modal-body");
    if ($modalBody.length === 1) {
      $modalBody.scrollTop(0);
    }
  },

  actions: {
    select: function() {
      this.set("selectedTab", this.get("tab"));
      this._resetModalScrollState();
    }
  }
});
