import Component from "@ember/component";
import { action } from "@ember/object";
import { empty, equal } from "@ember/object/computed";
// import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { classNames, tagName } from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import WatchedWord from "admin/models/watched-word";

@tagName("form")
@classNames("watched-word-form")
export default class WatchedWordForm extends Component {
  @service dialog;

  formSubmitted = false;
  actionKey = null;
  showMessage = false;
  isCaseSensitive = false;
  selectedTags = [];
  words = [];

  @empty("words") submitDisabled;

  @equal("actionKey", "replace") canReplace;

  @equal("actionKey", "tag") canTag;

  @equal("actionKey", "link") canLink;

  @discourseComputed("siteSettings.watched_words_regular_expressions")
  placeholderKey(watchedWordsRegularExpressions) {
    if (watchedWordsRegularExpressions) {
      return "admin.watched_words.form.placeholder_regexp";
    } else {
      return "admin.watched_words.form.placeholder";
    }
  }

  @observes("words.[]")
  removeMessage() {
    if (this.showMessage && !isEmpty(this.words)) {
      this.set("showMessage", false);
    }
  }

  @discourseComputed("words.[]")
  isUniqueWord(words) {
    const existingWords = this.filteredContent || [];
    const filtered = existingWords.filter(
      (content) => content.action === this.actionKey
    );

    const duplicate = filtered.find((content) => {
      if (content.case_sensitive === true) {
        return words.includes(content.word);
      } else {
        return words
          .map((w) => w.toLowerCase())
          .includes(content.word.toLowerCase());
      }
    });

    return !duplicate;
  }

  focusInput() {
    // schedule("afterRender", () => this.element.querySelector("input").focus());
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
        words: this.words,
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
            words: [],
            replacement: "",
            formSubmitted: false,
            selectedTags: [],
            showMessage: true,
            message: I18n.t("admin.watched_words.form.success"),
            isCaseSensitive: false,
          });
          result.words.forEach((word) => {
            this.action(WatchedWord.create(word));
          });
          // this.focusInput();
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
