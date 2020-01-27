import { sort } from "@ember/object/computed";
import EmberObjectProxy from "@ember/object/proxy";
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import ModalFunctionality from "discourse/mixins/modal-functionality";
const BufferedProxy = window.BufferedProxy; // import BufferedProxy from 'ember-buffered-proxy/proxy';
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import Ember from "ember";

export default Controller.extend(ModalFunctionality, Ember.Evented, {
  init() {
    this._super(...arguments);

    this.categoriesSorting = ["position"];
  },

  @discourseComputed("site.categories")
  categoriesBuffered(categories) {
    const bufProxy = EmberObjectProxy.extend(BufferedProxy);
    return categories.map(c => bufProxy.create({ content: c }));
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
      this.categoriesOrdered.forEach(category => {
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

    this.categoriesBuffered.forEach(bc => {
      if (bc.get("hasBufferedChanges")) {
        bc.applyBufferedChanges();
      }
    });

    this.notifyPropertyChange("categoriesBuffered");
  },

  move(category, direction) {
    let otherCategory;

    if (direction === -1) {
      // First category above current one
      const categoriesOrderedDesc = this.categoriesOrdered.reverse();
      otherCategory = categoriesOrderedDesc.find(
        c =>
          category.get("parent_category_id") === c.get("parent_category_id") &&
          c.get("position") < category.get("position")
      );
    } else if (direction === 1) {
      // First category under current one
      otherCategory = this.categoriesOrdered.find(
        c =>
          category.get("parent_category_id") === c.get("parent_category_id") &&
          c.get("position") > category.get("position")
      );
    } else {
      // Find category occupying target position
      otherCategory = this.categoriesOrdered.find(
        c => c.get("position") === category.get("position") + direction
      );
    }

    if (otherCategory) {
      // Try to swap positions of the two categories
      if (category.get("id") !== otherCategory.get("id")) {
        const currentPosition = category.get("position");
        category.set("position", otherCategory.get("position"));
        otherCategory.set("position", currentPosition);
      }
    } else if (direction < 0) {
      category.set("position", -1);
    } else if (direction > 0) {
      category.set("position", this.categoriesOrdered.length);
    }

    this.reorder();
  },

  actions: {
    change(category, event) {
      let newPosition = parseInt(event.target.value, 10);
      newPosition = Math.min(
        Math.max(newPosition, 0),
        this.categoriesOrdered.length - 1
      );

      this.move(category, newPosition - category.get("position"));
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
      this.categoriesBuffered.forEach(cat => {
        data[cat.get("id")] = cat.get("position");
      });

      ajax("/categories/reorder", {
        type: "POST",
        data: { mapping: JSON.stringify(data) }
      })
        .then(() => this.send("closeModal"))
        .catch(popupAjaxError);
    }
  }
});
