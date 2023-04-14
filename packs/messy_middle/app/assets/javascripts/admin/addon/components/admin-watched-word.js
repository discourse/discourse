import { classNames } from "@ember-decorators/component";
import { inject as service } from "@ember/service";
import { alias, equal } from "@ember/object/computed";
import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import I18n from "I18n";

@classNames("watched-word")
export default class AdminWatchedWord extends Component {
  @service dialog;

  @equal("actionKey", "replace") isReplace;

  @equal("actionKey", "tag") isTag;

  @equal("actionKey", "link") isLink;

  @alias("word.case_sensitive") isCaseSensitive;

  @discourseComputed("word.replacement")
  tags(replacement) {
    return replacement.split(",");
  }

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
  }
}
