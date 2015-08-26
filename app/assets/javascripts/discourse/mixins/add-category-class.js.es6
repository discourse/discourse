// Mix this in to a view that has a `categoryFullSlug` property to automatically
// add it to the body as the view is entered / left / model is changed.
// This is used for keeping the `body` style in sync for the background image.

import Ember from "ember";
const { on, observer } = Ember;

export default {
  _categoryChanged: on("didInsertElement", observer("categoryFullSlug", function() {
    const categoryFullSlug = this.get("categoryFullSlug");

    this._removeClass();

    if (categoryFullSlug) {
      $("body").addClass("category-" + categoryFullSlug);
    }
  })),

  _leave: on("willDestroyElement", function() {
    this.removeObserver("categoryFullSlug");
    this._removeClass();
  }),

  _removeClass() {
    $("body").removeClass((_, css) => (css.match(/\bcategory-\S+/g) || []).join(" "));
  },
};
