import EmberObject from "@ember/object";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { and } from "@ember/object/computed";

export default EmberObject.extend({
  sortable: null,
  ariaPressed: and("sortable", "isSorting"),

  @discourseComputed
  localizedName() {
    if (this.forceName) {
      return this.forceName;
    }

    return this.name ? I18n.t(this.name) : "";
  },

  @discourseComputed
  sortIcon() {
    const asc = this.parent.ascending ? "up" : "down";
    return `chevron-${asc}`;
  },

  @discourseComputed
  isSorting() {
    return this.sortable && this.parent.order === this.order;
  },

  @discourseComputed
  className() {
    const name = [];

    if (this.order) {
      name.push(this.order);
    }

    if (this.sortable) {
      name.push("sortable");

      if (this.isSorting) {
        name.push("sorting");
      }
    }

    if (this.number) {
      name.push("num");
    }

    return name.join(" ");
  },

  @discourseComputed
  ariaSort() {
    if (this.isSorting) {
      return this.parent.ascending ? "ascending" : "descending";
    } else {
      return false;
    }
  },
});
