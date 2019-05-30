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
  init() {
    this._super(...arguments);

    this.categoriesSorting = ["position"];
  },

  @on("init")
  _fixOrder() {
    this.fixIndices();
  },

  @computed("site.categories")
  categoriesBuffered(categories) {
    const bufProxy = Ember.ObjectProxy.extend(BufferedProxy);
    return categories.map(c => bufProxy.create({ content: c }));
  },

  categoriesOrdered: Ember.computed.sort(
    "categoriesBuffered",
    "categoriesSorting"
  ),

  @computed("categoriesBuffered.@each.hasBufferedChanges")
  showApplyAll() {
    let anyChanged = false;
    this.categoriesBuffered.forEach(bc => {
      anyChanged = anyChanged || bc.hasBufferedChanges;
    });
    return anyChanged;
  },

  moveDir(cat, dir) {
    const cats = this.categoriesOrdered;
    const curIdx = cat.position;
    let desiredIdx = curIdx + dir;
    if (desiredIdx >= 0 && desiredIdx < cats.length) {
      let otherCat = cats.objectAt(desiredIdx);

      // Respect children
      const parentIdx = otherCat.parent_category_id;
      if (parentIdx && parentIdx !== cat.parent_category_id) {
        if (parentIdx === cat.id) {
          // We want to move down
          for (let i = curIdx + 1; i < cats.length; i++) {
            let tmpCat = cats.objectAt(i);
            if (!tmpCat.parent_category_id) {
              desiredIdx = cats.indexOf(tmpCat);
              otherCat = tmpCat;
              break;
            }
          }
        } else {
          // We want to move up
          cats.forEach(function(tmpCat) {
            if (tmpCat.id === parentIdx) {
              desiredIdx = cats.indexOf(tmpCat);
              otherCat = tmpCat;
            }
          });
        }
      }

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
    const categories = this.categoriesOrdered;
    const subcategories = {};

    categories.forEach(category => {
      const parentCategoryId = category.parent_category_id;

      if (parentCategoryId) {
        subcategories[parentCategoryId] = subcategories[parentCategoryId] || [];
        subcategories[parentCategoryId].push(category);
      }
    });

    for (let i = 0, position = 0; i < categories.length; ++i) {
      const category = categories.objectAt(i);

      if (!category.parent_category_id) {
        category.set("position", position++);
        (subcategories[category.id] || []).forEach(subcategory =>
          subcategory.set("position", position++)
        );
      }
    }
  },

  actions: {
    change(cat, e) {
      let position = parseInt($(e.target).val());
      let amount = Math.min(
        Math.max(position, 0),
        this.categoriesOrdered.length - 1
      );
      this.moveDir(cat, amount - cat.position);
    },

    moveUp(cat) {
      this.moveDir(cat, -1);
    },
    moveDown(cat) {
      this.moveDir(cat, 1);
    },

    commit() {
      this.fixIndices();

      this.categoriesBuffered.forEach(bc => {
        if (bc.hasBufferedChanges) {
          bc.applyBufferedChanges();
        }
      });
      this.notifyPropertyChange("categoriesBuffered");
    },

    saveOrder() {
      this.send("commit");

      const data = {};
      this.categoriesBuffered.forEach(cat => {
        data[cat.id] = cat.position;
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
