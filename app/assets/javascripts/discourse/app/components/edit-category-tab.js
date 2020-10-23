import I18n from "I18n";
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

  _addToCollection: function () {
    this.panels.addObject(this.tabClassName);
  },

  @discourseComputed("params.slug", "params.parentSlug")
  fullSlug(slug, parentSlug) {
    const slugPart = parentSlug && slug ? `${parentSlug}/${slug}` : slug;
    return `/c/${slugPart}/edit/${this.tab}`;
  },
});
