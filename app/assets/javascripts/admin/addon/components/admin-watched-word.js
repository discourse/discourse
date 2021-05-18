import Component from "@ember/component";
import I18n from "I18n";
import bootbox from "bootbox";

export default Component.extend({
  classNames: ["watched-word"],

  click() {
    this.word
      .destroy()
      .then(() => {
        this.action(this.word);
      })
      .catch((e) => {
        bootbox.alert(
          I18n.t("generic_error_with_reason", {
            error: `http: ${e.status} - ${e.body}`,
          })
        );
      });
  },
});
