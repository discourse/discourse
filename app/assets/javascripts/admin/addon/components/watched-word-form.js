import discourseComputed, {
  observes,
  on,
} from "discourse-common/utils/decorators";
import Component from "@ember/component";
import I18n from "I18n";
import WatchedWord from "admin/models/watched-word";
import bootbox from "bootbox";
import { equal } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";
import { schedule } from "@ember/runloop";

export default Component.extend({
  classNames: ["watched-word-form"],
  formSubmitted: false,
  actionKey: null,
  showMessage: false,
  selectedTags: null,

  canReplace: equal("actionKey", "replace"),
  canTag: equal("actionKey", "tag"),
  canLink: equal("actionKey", "link"),

  didInsertElement() {
    this._super(...arguments);
    this.set("selectedTags", []);
  },

  @discourseComputed("siteSettings.watched_words_regular_expressions")
  placeholderKey(watchedWordsRegularExpressions) {
    if (watchedWordsRegularExpressions) {
      return "admin.watched_words.form.placeholder_regexp";
    } else {
      return "admin.watched_words.form.placeholder";
    }
  },

  @observes("word")
  removeMessage() {
    if (this.showMessage && !isEmpty(this.word)) {
      this.set("showMessage", false);
    }
  },

  @discourseComputed("word")
  isUniqueWord(word) {
    const words = this.filteredContent || [];
    const filtered = words.filter(
      (content) => content.action === this.actionKey
    );
    return filtered.every(
      (content) => content.word.toLowerCase() !== word.toLowerCase()
    );
  },

  actions: {
    changeSelectedTags(tags) {
      this.setProperties({
        selectedTags: tags,
        replacement: tags.join(","),
      });
    },

    submit() {
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
            });
            this.action(WatchedWord.create(result));
            schedule("afterRender", () =>
              this.element.querySelector(".watched-word-input").focus()
            );
          })
          .catch((e) => {
            this.set("formSubmitted", false);
            const msg =
              e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors
                ? I18n.t("generic_error_with_reason", {
                    error: e.jqXHR.responseJSON.errors.join(". "),
                  })
                : I18n.t("generic_error");
            bootbox.alert(msg, () =>
              this.element.querySelector(".watched-word-input").focus()
            );
          });
      }
    },
  },

  @on("didInsertElement")
  _init() {
    schedule("afterRender", () => {
      $(this.element.querySelector(".watched-word-input")).keydown((e) => {
        if (e.keyCode === 13) {
          this.send("submit");
        }
      });
    });
  },
});
