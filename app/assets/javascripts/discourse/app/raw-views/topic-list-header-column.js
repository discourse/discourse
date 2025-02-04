import EmberObject from "@ember/object";
import { and } from "@ember/object/computed";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class TopicListHeaderColumn extends EmberObject {
  sortable = null;

  @and("sortable", "isSorting") ariaPressed;

  @discourseComputed
  localizedName() {
    if (this.forceName) {
      return this.forceName;
    }

    return this.name ? i18n(this.name) : "";
  }

  @discourseComputed
  sortIcon() {
    const isAscending =
      (
        this.parent.ascending ||
        this.parent.context?.ascending ||
        ""
      ).toString() === "true";

    return `chevron-${isAscending ? "up" : "down"}`;
  }

  @discourseComputed
  isSorting() {
    return (
      this.sortable &&
      (this.parent.order === this.order ||
        this.parent.context?.order === this.order)
    );
  }

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

  @discourseComputed
  ariaSort() {
    if (this.isSorting) {
      return this.parent.ascending ? "ascending" : "descending";
    } else {
      return false;
    }
  }
}
