import { assert, deprecate } from "@ember/debug";
import EmberObject from "@ember/object";
import Component from "@ember/component";
import jQuery from "jquery";

let done = false;

// Adapted from https://github.com/emberjs/ember-jquery/blob/master/vendor/jquery/component.dollar.js
// but implemented in a module to avoid transpiled version triggering the Ember Global deprecation.
// To be dropped when we remove the jquery integration as part of the 4.x update.
export default {
  name: "deprecate-jquery-integration",

  initialize() {
    if (done) {
      return;
    }

    EmberObject.reopen.call(Component, {
      $(sel) {
        assert(
          "You cannot access this.$() on a component with `tagName: ''` specified.",
          this.tagName !== ""
        );

        deprecate(
          "Using this.$() in a component has been deprecated, consider using this.element",
          false,
          {
            id: "ember-views.curly-components.jquery-element",
            since: "3.4.0",
            until: "4.0.0",
            url: "https://emberjs.com/deprecations/v3.x#toc_jquery-apis",
            for: "ember-source",
          }
        );

        if (this.element) {
          return sel ? jQuery(sel, this.element) : jQuery(this.element);
        }
      },
    });

    done = true;
  },
};
