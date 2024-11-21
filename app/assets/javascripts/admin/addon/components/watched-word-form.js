import Component from "@ember/component";
import { action } from "@ember/object";
import { empty, equal } from "@ember/object/computed";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { classNames, tagName } from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import WatchedWord from "admin/models/watched-word";

@tagName("form")
@classNames("watched-word-form")
export default class WatchedWordForm extends Component {
  @service dialog;

  formSubmitted = false;
  actionKey = null;
  showMessage = false;
  isCaseSensitive = false;
  isHtml = false;
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

  @observes("actionKey")
  actionChanged() {
    this.setProperties({
      showMessage: false,
    });
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
        message: i18n("admin.watched_words.form.exists"),
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
        isHtml: this.isHtml,
      });

      watchedWord
        .save()
        .then((result) => {
          this.setProperties({
            words: [],
            replacement: "",
            selectedTags: [],
            showMessage: true,
            message: i18n("admin.watched_words.form.success"),
            isCaseSensitive: false,
            isHtml: false,
          });
          if (result.words) {
            result.words.forEach((word) => {
              this.action(WatchedWord.create(word));
            });
          } else {
            this.action(result);
          }
        })
        .catch(popupAjaxError)
        .finally(this.set("formSubmitted", false));
    }
  }
}
