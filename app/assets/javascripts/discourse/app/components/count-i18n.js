import Component from "@ember/component";

export default Component.extend({
  tagName: "span",
  rerenderTriggers: ["count", "suffix"],
  i18nCount: null,

  didReceiveAttrs() {
    this._super(...arguments);
    this.set(
      "i18nCount",
      I18n.t(this.key + (this.suffix || ""), { count: this.count }).htmlSafe()
    );
  }
});
