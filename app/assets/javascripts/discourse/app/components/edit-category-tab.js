import Component from "@ember/component";
import { action } from "@ember/object";
import { empty } from "@ember/object/computed";
import { scheduleOnce } from "@ember/runloop";
import { underscore } from "@ember/string";
import { propertyEqual } from "discourse/lib/computed";
import DiscourseURL from "discourse/lib/url";
import getURL from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default Component.extend({
  tagName: "li",
  classNameBindings: ["active", "tabClassName"],
  newCategory: empty("params.slug"),

  @discourseComputed("tab")
  tabClassName(tab) {
    return "edit-category-" + tab;
  },

  active: propertyEqual("selectedTab", "tab"),

  @discourseComputed("tab")
  title(tab) {
    return I18n.t(`category.${underscore(tab)}`);
  },

  didInsertElement() {
    this._super(...arguments);
    scheduleOnce("afterRender", this, this._addToCollection);
  },

  willDestroyElement() {
    this._super(...arguments);

    this.setProperties({
      selectedTab: "general",
      params: {},
    });
  },

  _addToCollection() {
    this.panels.addObject(this.tabClassName);
  },

  @discourseComputed("params.slug", "params.parentSlug")
  fullSlug(slug, parentSlug) {
    const slugPart = parentSlug && slug ? `${parentSlug}/${slug}` : slug;
    return getURL(`/c/${slugPart}/edit/${this.tab}`);
  },

  @action
  select(event) {
    event?.preventDefault();
    this.set("selectedTab", this.tab);
    if (!this.newCategory) {
      DiscourseURL.routeTo(this.fullSlug);
    }
  },
});
