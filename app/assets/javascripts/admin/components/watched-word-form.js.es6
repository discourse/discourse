import { schedule } from "@ember/runloop";
import Component from "@ember/component";
import WatchedWord from "admin/models/watched-word";
import {
  default as computed,
  on,
  observes
} from "ember-addons/ember-computed-decorators";

export default Component.extend({
  classNames: ["watched-word-form"],
  formSubmitted: false,
  actionKey: null,
  showMessage: false,

  @computed("regularExpressions")
  placeholderKey(regularExpressions) {
    return (
      "admin.watched_words.form.placeholder" +
      (regularExpressions ? "_regexp" : "")
    );
  },

  @observes("word")
  removeMessage() {
    if (this.showMessage && !Ember.isEmpty(this.word)) {
      this.set("showMessage", false);
    }
  },

  @computed("word")
  isUniqueWord(word) {
    const words = this.filteredContent || [];
    const filtered = words.filter(content => content.action === this.actionKey);
    return filtered.every(
      content => content.word.toLowerCase() !== word.toLowerCase()
    );
  },

  actions: {
    submit() {
      if (!this.isUniqueWord) {
        this.setProperties({
          showMessage: true,
          message: I18n.t("admin.watched_words.form.exists")
        });
        return;
      }

      if (!this.formSubmitted) {
        this.set("formSubmitted", true);

        const watchedWord = WatchedWord.create({
          word: this.word,
          action: this.actionKey
        });

        watchedWord
          .save()
          .then(result => {
            this.setProperties({
              word: "",
              formSubmitted: false,
              showMessage: true,
              message: I18n.t("admin.watched_words.form.success")
            });
            this.action(WatchedWord.create(result));
            schedule("afterRender", () =>
              this.element.querySelector(".watched-word-input").focus()
            );
          })
          .catch(e => {
            this.set("formSubmitted", false);
            const msg =
              e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors
                ? I18n.t("generic_error_with_reason", {
                    error: e.jqXHR.responseJSON.errors.join(". ")
                  })
                : I18n.t("generic_error");
            bootbox.alert(msg, () =>
              this.element.querySelector(".watched-word-input").focus()
            );
          });
      }
    }
  },

  @on("didInsertElement")
  _init() {
    schedule("afterRender", () => {
      $(this.element.querySelector(".watched-word-input")).keydown(e => {
        if (e.keyCode === 13) {
          this.send("submit");
        }
      });
    });
  }
});
