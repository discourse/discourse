import Component from "@ember/component";
import { action } from "@ember/object";
import { sort } from "@ember/object/computed";
import { next } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class ReorderCategories extends Component {
  @service site;

  categoriesSorting = ["position"];

  @sort("site.categories", "categoriesSorting") categoriesOrdered;

  init() {
    super.init(...arguments);
    next(() => this.reorder());
  }

  /**
   * 1. Make sure all categories have unique position numbers.
   * 2. Place sub-categories after their parent categories while maintaining
   *    the same relative order.
   *
   *    e.g.
   *      parent/c2/c1          parent
   *      parent/c1             parent/c1
   *      parent          =>    parent/c2
   *      other                 parent/c2/c1
   *      parent/c2             other
   **/
  reorder() {
    this.reorderChildren(null, 0, 0);
  }

  reorderChildren(categoryId, depth, index) {
    for (const category of this.categoriesOrdered) {
      if (
        (categoryId === null && !category.get("parent_category_id")) ||
        category.get("parent_category_id") === categoryId
      ) {
        category.setProperties({ depth, position: index++ });
        index = this.reorderChildren(category.get("id"), depth + 1, index);
      }
    }

    return index;
  }

  countDescendants(category) {
    if (!category.get("subcategories")) {
      return 0;
    }

    return category
      .get("subcategories")
      .reduce(
        (count, subcategory) => count + this.countDescendants(subcategory),
        category.get("subcategories").length
      );
  }

  @action
  move(category, direction) {
    let targetPosition = category.get("position") + direction;

    // Adjust target position for sub-categories
    if (direction > 0) {
      // Moving down (position gets larger)
      if (category.get("isParent")) {
        // This category has subcategories, adjust targetPosition to account for them
        let offset = this.countDescendants(category);
        if (direction <= offset) {
          // Only apply offset if target position is occupied by a subcategory
          // Seems weird but fixes a UX quirk
          targetPosition += offset;
        }
      }
    } else {
      // Moving up (position gets smaller)
      const otherCategory = this.categoriesOrdered.find(
        (c) =>
          // find category currently at targetPosition
          c.get("position") === targetPosition
      );
      if (otherCategory && otherCategory.get("ancestors")) {
        // Target category is a subcategory, adjust targetPosition to account for ancestors
        const highestAncestor = otherCategory
          .get("ancestors")
          .reduce((current, min) =>
            current.get("position") < min.get("position") ? current : min
          );
        targetPosition = highestAncestor.get("position");
      }
    }

    // Adjust target position for range bounds
    if (targetPosition >= this.categoriesOrdered.length) {
      // Set to max
      targetPosition = this.categoriesOrdered.length - 1;
    } else if (targetPosition < 0) {
      // Set to min
      targetPosition = 0;
    }

    // Update other categories between current and target position
    for (const c of this.categoriesOrdered) {
      if (direction < 0) {
        // Moving up (position gets smaller)
        if (
          c.get("position") < category.get("position") &&
          c.get("position") >= targetPosition
        ) {
          const newPosition = c.get("position") + 1;
          c.set("position", newPosition);
        }
      } else {
        // Moving down (position gets larger)
        if (
          c.get("position") > category.get("position") &&
          c.get("position") <= targetPosition
        ) {
          const newPosition = c.get("position") - 1;
          c.set("position", newPosition);
        }
      }
    }

    // Update this category's position to target position
    category.set("position", targetPosition);

    this.reorder();
  }

  @action
  change(category, event) {
    let newPosition = parseFloat(event.target.value);
    newPosition =
      newPosition < category.get("position")
        ? Math.ceil(newPosition)
        : Math.floor(newPosition);
    const direction = newPosition - category.get("position");
    this.move(category, direction);
  }

  @action
  async save() {
    this.reorder();

    const data = {};
    for (const category of this.site.categories) {
      data[category.get("id")] = category.get("position");
    }

    try {
      await ajax("/categories/reorder", {
        type: "POST",
        data: { mapping: JSON.stringify(data) },
      });
      window.location.reload();
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
