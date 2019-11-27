import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import { escapeExpression } from "discourse/lib/utilities";

export default Component.extend({
  classNames: ["watched-word"],
  watchedWord: null,
  xIcon: iconHTML("times").htmlSafe(),

  init() {
    this._super(...arguments);
    this.set("watchedWord", `${escapeExpression(this.get("word.word"))}`);
  },

  click() {
    this.word
      .destroy()
      .then(() => {
        this.action(this.word);
      })
      .catch(e => {
        bootbox.alert(
          I18n.t("generic_error_with_reason", {
            error: `http: ${e.status} - ${e.body}`
          })
        );
      });
  }
});
