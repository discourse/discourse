import UrlRefresh from "discourse/mixins/url-refresh";
import { on } from "ember-addons/ember-computed-decorators";

const CATEGORIES_LIST_BODY_CLASS = "categories-list";

export default Ember.Component.extend(UrlRefresh, {
  classNames: ["contents"],

  @on("didInsertElement")
  addBodyClass() {
    $("body").addClass(CATEGORIES_LIST_BODY_CLASS);
  },

  @on("willDestroyElement")
  removeBodyClass() {
    $("body").removeClass(CATEGORIES_LIST_BODY_CLASS);
  }
});
