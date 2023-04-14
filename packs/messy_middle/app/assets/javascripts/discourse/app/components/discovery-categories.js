import Component from "@ember/component";
import UrlRefresh from "discourse/mixins/url-refresh";

const CATEGORIES_LIST_BODY_CLASS = "categories-list";

export default Component.extend(UrlRefresh, {
  classNames: ["contents"],

  didInsertElement() {
    this._super(...arguments);

    document.body.classList.add(CATEGORIES_LIST_BODY_CLASS);
  },

  willDestroyElement() {
    this._super(...arguments);

    document.body.classList.remove(CATEGORIES_LIST_BODY_CLASS);
  },
});
