import EmberObject from "@ember/object";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default EmberObject.extend({
  @computed
  localizedName() {
    if (this.forceName) {
      return this.forceName;
    }

    return this.name ? I18n.t(this.name) : "";
  },

  @computed
  sortIcon() {
    const asc = this.parent.ascending ? "up" : "down";
    return `chevron-${asc}`;
  },

  @computed
  isSorting() {
    return this.sortable && this.parent.order === this.order;
  },

  @computed
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
