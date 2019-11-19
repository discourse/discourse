import Component from "@ember/component";
import UrlRefresh from "discourse/mixins/url-refresh";
import { on } from "discourse-common/utils/decorators";

const CATEGORIES_LIST_BODY_CLASS = "categories-list";

export default Component.extend(UrlRefresh, {
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
