import { ajax } from "discourse/lib/ajax";
import ModalFunctionality from "discourse/mixins/modal-functionality";
const BufferedProxy = window.BufferedProxy; // import BufferedProxy from 'ember-buffered-proxy/proxy';
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  on,
  default as computed
} from "ember-addons/ember-computed-decorators";
import Ember from "ember";

export default Ember.Controller.extend(ModalFunctionality, Ember.Evented, {
  @on("init")
  _fixOrder() {
    this.fixIndices();
  },

  @computed("site.categories")
  categoriesBuffered(categories) {
    const bufProxy = Ember.ObjectProxy.extend(BufferedProxy);
    return categories.map(c => bufProxy.create({ content: c }));
  },

  categoriesSorting: ["position"],
  categoriesOrdered: Ember.computed.sort(
    "categoriesBuffered",
    "categoriesSorting"
  ),

  showApplyAll: function() {
    let anyChanged = false;
    this.get("categoriesBuffered").forEach(bc => {
      anyChanged = anyChanged || bc.get("hasBufferedChanges");
    });
    return anyChanged;
  }.property("categoriesBuffered.@each.hasBufferedChanges"),

  moveDir(cat, dir) {
    const cats = this.get("categoriesOrdered");
    const curIdx = cats.indexOf(cat);
    const desiredIdx = curIdx + dir;
    if (desiredIdx >= 0 && desiredIdx < cats.get("length")) {
      const otherCat = cats.objectAt(desiredIdx);
      otherCat.set("position", curIdx);
      cat.set("position", desiredIdx);
      this.send("commit");
    }
  },

  /**
    1. Make sure all categories have unique position numbers.
    2. Place sub-categories after their parent categories while maintaining the
        same relative order.

        e.g.
          parent/c1         parent
          parent      =>    parent/c1
          other             parent/c2
          parent/c2         other
  **/
  fixIndices() {
    const categories = this.get("categoriesOrdered");
    const subcategories = {};

    categories.forEach(category => {
      const parentCategoryId = category.get("parent_category_id");

      if (parentCategoryId) {
        subcategories[parentCategoryId] = subcategories[parentCategoryId] || [];
        subcategories[parentCategoryId].push(category);
      }
    });

    for (let i = 0, position = 0; i < categories.get("length"); ++i) {
      const category = categories.objectAt(i);

      if (!category.get("parent_category_id")) {
        category.set("position", position++);
        (subcategories[category.get("id")] || []).forEach(subcategory =>
          subcategory.set("position", position++)
        );
      }
    }
  },

  actions: {
    change(cat, e) {
      let position = parseInt($(e.target).val());
      cat.set("position", position);
      this.fixIndices();
    },

    moveUp(cat) {
      this.moveDir(cat, -1);
    },
    moveDown(cat) {
      this.moveDir(cat, 1);
    },

    commit() {
      this.fixIndices();

      this.get("categoriesBuffered").forEach(bc => {
        if (bc.get("hasBufferedChanges")) {
          bc.applyBufferedChanges();
        }
      });
      this.notifyPropertyChange("categoriesBuffered");
    },

    saveOrder() {
      this.send("commit");

      const data = {};
      this.get("categoriesBuffered").forEach(cat => {
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
