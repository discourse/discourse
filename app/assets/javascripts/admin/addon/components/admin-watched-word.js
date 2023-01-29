import Component from "@ember/component";
import { alias, equal } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import I18n from "I18n";
import { inject as service } from "@ember/service";

export default Component.extend({
  classNames: ["watched-word"],
  dialog: service(),

  isReplace: equal("actionKey", "replace"),
  isTag: equal("actionKey", "tag"),
  isLink: equal("actionKey", "link"),
  isCaseSensitive: alias("word.case_sensitive"),

  @discourseComputed("word.replacement")
  tags(replacement) {
    return replacement.split(",");
  },

  @action
  deleteWord() {
    this.word
      .destroy()
      .then(() => {
        this.action(this.word);
      })
      .catch((e) => {
        this.dialog.alert(
          I18n.t("generic_error_with_reason", {
            error: `http: ${e.status} - ${e.body}`,
          })
        );
      });
  },
});
