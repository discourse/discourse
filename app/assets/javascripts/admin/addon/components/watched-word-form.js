import { action } from "@ember/object";
import { classNames, tagName } from "@ember-decorators/component";
import { inject as service } from "@ember/service";
import { equal, not } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { observes } from "@ember-decorators/object";
import Component from "@ember/component";
import I18n from "I18n";
import WatchedWord from "admin/models/watched-word";
import { isEmpty } from "@ember/utils";
import { schedule } from "@ember/runloop";

@tagName("form")
@classNames("watched-word-form")
export default class WatchedWordForm extends Component {
  @service dialog;

  formSubmitted = false;
  actionKey = null;
  showMessage = false;
  selectedTags = null;
  isCaseSensitive = false;

  @not("word") submitDisabled;

  @equal("actionKey", "replace") canReplace;

  @equal("actionKey", "tag") canTag;

  @equal("actionKey", "link") canLink;

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.set("selectedTags", []);
  }

  @discourseComputed("siteSettings.watched_words_regular_expressions")
  placeholderKey(watchedWordsRegularExpressions) {
    if (watchedWordsRegularExpressions) {
      return "admin.watched_words.form.placeholder_regexp";
    } else {
      return "admin.watched_words.form.placeholder";
    }
  }

  @observes("word")
  removeMessage() {
    if (this.showMessage && !isEmpty(this.word)) {
      this.set("showMessage", false);
    }
  }

  @discourseComputed("word")
  isUniqueWord(word) {
    const words = this.filteredContent || [];
    const filtered = words.filter(
      (content) => content.action === this.actionKey
    );
    return filtered.every((content) => {
      if (content.case_sensitive === true) {
        return content.word !== word;
      }
      return content.word.toLowerCase() !== word.toLowerCase();
    });
  }

  focusInput() {
    schedule("afterRender", () => this.element.querySelector("input").focus());
  }

  @action
  changeSelectedTags(tags) {
    this.setProperties({
      selectedTags: tags,
      replacement: tags.join(","),
    });
  }

  @action
  submitForm() {
    if (!this.isUniqueWord) {
      this.setProperties({
        showMessage: true,
        message: I18n.t("admin.watched_words.form.exists"),
      });
      return;
    }

    if (!this.formSubmitted) {
      this.set("formSubmitted", true);

      const watchedWord = WatchedWord.create({
        word: this.word,
        replacement:
          this.canReplace || this.canTag || this.canLink
            ? this.replacement
            : null,
        action: this.actionKey,
        isCaseSensitive: this.isCaseSensitive,
      });

      watchedWord
        .save()
        .then((result) => {
          this.setProperties({
            word: "",
            replacement: "",
            formSubmitted: false,
            selectedTags: [],
            showMessage: true,
            message: I18n.t("admin.watched_words.form.success"),
            isCaseSensitive: false,
          });
          this.action(WatchedWord.create(result));
          this.focusInput();
        })
        .catch((e) => {
          this.set("formSubmitted", false);
          const message = e.jqXHR.responseJSON?.errors
            ? I18n.t("generic_error_with_reason", {
                error: e.jqXHR.responseJSON.errors.join(". "),
              })
            : I18n.t("generic_error");
          this.dialog.alert({
            message,
            didConfirm: () => this.focusInput(),
            didCancel: () => this.focusInput(),
          });
        });
    }
  }
}
