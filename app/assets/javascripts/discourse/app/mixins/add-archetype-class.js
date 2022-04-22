import { observes, on } from "discourse-common/utils/decorators";

// Mix this in to a view that has a `archetype` property to automatically
// add it to the body as the view is entered / left / model is changed.
// This is used for keeping the `body` style in sync for the background image.
export default {
  _cleanUp() {
    document.body.classList.forEach((name) => {
      if (/\barchetype-\S+/g.test(name)) {
        document.body.classList.remove(name);
      }
    });
  },

  @observes("archetype")
  @on("init")
  _archetypeChanged() {
    this._cleanUp();

    if (this.archetype) {
      document.body.classList.add(`archetype-${this.archetype}`);
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    this._cleanUp();
  },
};
