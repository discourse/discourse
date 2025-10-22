/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { empty } from "@ember/object/computed";
import { scheduleOnce } from "@ember/runloop";
import { underscore } from "@ember/string";
import { classNameBindings, tagName } from "@ember-decorators/component";
import { propertyEqual } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

@tagName("li")
@classNameBindings("active", "tabClassName")
export default class EditCategoryTab extends Component {
  @empty("params.slug") newCategory;
  @propertyEqual("selectedTab", "tab") active;

  @discourseComputed("tab")
  tabClassName(tab) {
    return "edit-category-" + tab;
  }

  @discourseComputed("tab")
  title(tab) {
    return i18n(`category.${underscore(tab)}`);
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    scheduleOnce("afterRender", this, this._addToCollection);
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    this.setProperties({
      selectedTab: "general",
      params: {},
    });
  }

  _addToCollection() {
    this.panels.addObject(this.tabClassName);
  }

  @discourseComputed("params.slug", "params.parentSlug")
  fullSlug(slug, parentSlug) {
    const slugPart = parentSlug && slug ? `${parentSlug}/${slug}` : slug;
    return getURL(`/c/${slugPart}/edit/${this.tab}`);
  }

  @action
  select(event) {
    event?.preventDefault();
    this.set("selectedTab", this.tab);
    if (!this.newCategory) {
      DiscourseURL.routeTo(this.fullSlug);
    }
  }

  <template>
    <a
      href
      {{on "click" this.select}}
      class={{if this.active "active"}}
    >{{this.title}}</a>
  </template>
}
