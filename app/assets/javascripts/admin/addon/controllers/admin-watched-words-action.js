import Controller, { inject as controller } from "@ember/controller";
import I18n from "I18n";
import WatchedWord from "admin/models/watched-word";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import discourseComputed from "discourse-common/utils/decorators";
import { fmt } from "discourse/lib/computed";
import { or } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import showModal from "discourse/lib/show-modal";

export default Controller.extend({
  adminWatchedWords: controller(),
  actionNameKey: null,
  downloadLink: fmt(
    "actionNameKey",
    "/admin/customize/watched_words/action/%@/download"
  ),
  showWordsList: or("adminWatchedWords.showWords", "adminWatchedWords.filter"),

  findAction(actionName) {
    return (this.adminWatchedWords.model || []).findBy("nameKey", actionName);
  },

  @discourseComputed("actionNameKey", "adminWatchedWords.model")
  currentAction(actionName) {
    return this.findAction(actionName);
  },

  @discourseComputed("currentAction.words.[]")
  regexpError(words) {
    for (const { regexp, word } of words) {
      try {
        RegExp(regexp);
      } catch {
        return I18n.t("admin.watched_words.invalid_regex", { word });
      }
    }
  },

  @discourseComputed("actionNameKey")
  actionDescription(actionNameKey) {
    return I18n.t("admin.watched_words.action_descriptions." + actionNameKey);
  },

  actions: {
    recordAdded(arg) {
      const action = this.findAction(this.actionNameKey);
      if (!action) {
        return;
      }

      action.words.unshiftObject(arg);
      schedule("afterRender", () => {
        // remove from other actions lists
        let match = null;
        this.adminWatchedWords.model.forEach((otherAction) => {
          if (match) {
            return;
          }

          if (otherAction.nameKey !== this.actionNameKey) {
            match = otherAction.words.findBy("id", arg.id);
            if (match) {
              otherAction.words.removeObject(match);
            }
          }
        });
      });
    },

    recordRemoved(arg) {
      if (this.currentAction) {
        this.currentAction.words.removeObject(arg);
      }
    },

    uploadComplete() {
      WatchedWord.findAll().then((data) => {
        this.adminWatchedWords.set("model", data);
      });
    },

    test() {
      WatchedWord.findAll().then((data) => {
        this.adminWatchedWords.set("model", data);
        showModal("admin-watched-word-test", {
          admin: true,
          model: this.currentAction,
        });
      });
    },

    clearAll() {
      const actionKey = this.actionNameKey;
      bootbox.confirm(
        I18n.t("admin.watched_words.clear_all_confirm", {
          action: I18n.t("admin.watched_words.actions." + actionKey),
        }),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        (result) => {
          if (result) {
            ajax(`/admin/customize/watched_words/action/${actionKey}.json`, {
              type: "DELETE",
            }).then(() => {
              const action = this.findAction(actionKey);
              if (action) {
                action.set("words", []);
              }
            });
          }
        }
      );
    },
  },
});
