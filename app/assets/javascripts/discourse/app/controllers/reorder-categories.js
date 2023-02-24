import discourseComputed, { on } from "discourse-common/utils/decorators";
import BufferedProxy from "ember-buffered-proxy/proxy";
import Controller from "@ember/controller";
import Evented from "@ember/object/evented";
import Modal from "discourse/controllers/modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { sort } from "@ember/object/computed";

export default Controller.extend(ModalFunctionality, Evented, {
  init() {
    this._super(...arguments);
    this.categoriesSorting = ["position"];
  },

  @discourseComputed("site.categories.[]")
  categoriesBuffered(categories) {
    return (categories || []).map((c) => BufferedProxy.create({ content: c }));
  },

  categoriesOrdered: sort("categoriesBuffered", "categoriesSorting"),

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
   *
   **/
  @on("init")
  reorder() {
    const reorderChildren = (categoryId, depth, index) => {
      this.categoriesOrdered.forEach((category) => {
        if (
          (categoryId === null && !category.get("parent_category_id")) ||
          category.get("parent_category_id") === categoryId
        ) {
          category.setProperties({ depth, position: index++ });
          index = reorderChildren(category.get("id"), depth + 1, index);
        }
      });

      return index;
    };

    reorderChildren(null, 0, 0);

    this.categoriesBuffered.forEach((bc) => {
      if (bc.get("hasBufferedChanges")) {
        bc.applyBufferedChanges();
      }
    });

    this.notifyPropertyChange("categoriesBuffered");
  },

  countDescendants(category) {
    return category.get("subcategories")
      ? category
          .get("subcategories")
          .reduce(
            (count, subcategory) => count + this.countDescendants(subcategory),
            category.get("subcategories").length
          )
      : 0;
  },

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
    this.categoriesOrdered.map((c) => {
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
    });

    // Update this category's position to target position
    category.set("position", targetPosition);

    this.reorder();
  },

  actions: {
    change(category, event) {
      let newPosition = parseFloat(event.target.value);
      newPosition =
        newPosition < category.get("position")
          ? Math.ceil(newPosition)
          : Math.floor(newPosition);
      const direction = newPosition - category.get("position");
      this.move(category, direction);
    },

    moveUp(category) {
      this.move(category, -1);
    },

    moveDown(category) {
      this.move(category, 1);
    },

    save() {
      this.reorder();

      const data = {};
      this.categoriesBuffered.forEach((cat) => {
        data[cat.get("id")] = cat.get("position");
      });

      ajax("/categories/reorder", {
        type: "POST",
        data: { mapping: JSON.stringify(data) },
      })
        .then(() => window.location.reload())
        .catch(popupAjaxError);
    },
  },
});
