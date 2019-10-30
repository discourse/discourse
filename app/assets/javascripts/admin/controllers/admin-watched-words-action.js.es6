import { schedule } from "@ember/runloop";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";
import WatchedWord from "admin/models/watched-word";
import { ajax } from "discourse/lib/ajax";
import { fmt } from "discourse/lib/computed";
import showModal from "discourse/lib/show-modal";

export default Controller.extend({
  actionNameKey: null,
  adminWatchedWords: inject(),
  showWordsList: Ember.computed.or(
    "adminWatchedWords.filtered",
    "adminWatchedWords.showWords"
  ),
  downloadLink: fmt(
    "actionNameKey",
    "/admin/logs/watched_words/action/%@/download"
  ),

  findAction(actionName) {
    return (this.get("adminWatchedWords.model") || []).findBy(
      "nameKey",
      actionName
    );
  },

  @computed("actionNameKey", "adminWatchedWords.model")
  currentAction(actionName) {
    return this.findAction(actionName);
  },

  @computed("currentAction.words.[]", "adminWatchedWords.model")
  filteredContent(words) {
    return words || [];
  },

  @computed("actionNameKey")
  actionDescription(actionNameKey) {
    return I18n.t("admin.watched_words.action_descriptions." + actionNameKey);
  },

  @computed("currentAction.count")
  wordCount(count) {
    return count || 0;
  },

  actions: {
    recordAdded(arg) {
      const a = this.findAction(this.actionNameKey);
      if (a) {
        a.words.unshiftObject(arg);
        a.incrementProperty("count");
        schedule("afterRender", () => {
          // remove from other actions lists
          let match = null;
          this.get("adminWatchedWords.model").forEach(action => {
            if (match) return;

            if (action.nameKey !== this.actionNameKey) {
              match = action.words.findBy("id", arg.id);
              if (match) {
                action.words.removeObject(match);
                action.decrementProperty("count");
              }
            }
          });
        });
      }
    },

    recordRemoved(arg) {
      if (this.currentAction) {
        this.currentAction.words.removeObject(arg);
        this.currentAction.decrementProperty("count");
      }
    },

    uploadComplete() {
      WatchedWord.findAll().then(data => {
        this.set("adminWatchedWords.model", data);
      });
    },

    clearAll() {
      const actionKey = this.actionNameKey;
      bootbox.confirm(
        I18n.t(`admin.watched_words.clear_all_confirm_${actionKey}`),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            ajax(`/admin/logs/watched_words/action/${actionKey}.json`, {
              method: "DELETE"
            }).then(() => {
              const action = this.findAction(actionKey);
              if (action) {
                action.setProperties({
                  words: [],
                  count: 0
                });
              }
            });
          }
        }
      );
    },

    test() {
      WatchedWord.findAll().then(data => {
        this.set("adminWatchedWords.model", data);
        showModal("admin-watched-word-test", {
          admin: true,
          model: this.currentAction
        });
      });
    }
  }
});
