import EmberObject from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default EmberObject.extend({
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
  }
});
