import Component from "@ember/component";
import { equal } from "@ember/object/computed";
import bootbox from "bootbox";
import discourseComputed from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import I18n from "I18n";

export default Component.extend({
  classNames: ["watched-word"],

  isReplace: equal("actionKey", "replace"),
  isTag: equal("actionKey", "tag"),
  isLink: equal("actionKey", "link"),

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
        bootbox.alert(
          I18n.t("generic_error_with_reason", {
            error: `http: ${e.status} - ${e.body}`,
          })
        );
      });
  },
});
