import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { or } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";
import I18n from "I18n";
import WatchedWord from "admin/models/watched-word";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";
import { fmt } from "discourse/lib/computed";
import { schedule } from "@ember/runloop";
import WatchedWordTestModal from "admin/components/modal/watched-word-test";

export default class AdminWatchedWordsActionController extends Controller {
  @service dialog;
  @service modal;
  @controller adminWatchedWords;

  actionNameKey = null;

  @fmt("actionNameKey", "/admin/customize/watched_words/action/%@/download")
  downloadLink;

  @or("adminWatchedWords.showWords", "adminWatchedWords.filter")
  showWordsList;

  findAction(actionName) {
    return (this.adminWatchedWords.model || []).findBy("nameKey", actionName);
  }

  @discourseComputed("actionNameKey", "adminWatchedWords.model")
  currentAction(actionName) {
    return this.findAction(actionName);
  }

  @discourseComputed("currentAction.words.[]")
  regexpError(words) {
    for (const { regexp, word } of words) {
      try {
        RegExp(regexp);
      } catch {
        return I18n.t("admin.watched_words.invalid_regex", { word });
      }
    }
  }

  @discourseComputed("actionNameKey")
  actionDescription(actionNameKey) {
    return I18n.t("admin.watched_words.action_descriptions." + actionNameKey);
  }

  @action
  recordAdded(arg) {
    const foundAction = this.findAction(this.actionNameKey);
    if (!foundAction) {
      return;
    }

    foundAction.words.unshiftObject(arg);
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
  }

  @action
  recordRemoved(arg) {
    if (this.currentAction) {
      this.currentAction.words.removeObject(arg);
    }
  }

  @action
  uploadComplete() {
    WatchedWord.findAll().then((data) => {
      this.adminWatchedWords.set("model", data);
    });
  }

  @action
  test() {
    WatchedWord.findAll().then((data) => {
      this.adminWatchedWords.set("model", data);
      this.modal.show(WatchedWordTestModal, {
        model: { watchedWord: this.currentAction },
      });
    });
  }

  @action
  clearAll() {
    const actionKey = this.actionNameKey;
    this.dialog.yesNoConfirm({
      message: I18n.t("admin.watched_words.clear_all_confirm", {
        action: I18n.t("admin.watched_words.actions." + actionKey),
      }),
      didConfirm: () => {
        ajax(`/admin/customize/watched_words/action/${actionKey}.json`, {
          type: "DELETE",
        }).then(() => {
          const foundAction = this.findAction(actionKey);
          if (foundAction) {
            foundAction.set("words", []);
          }
        });
      },
    });
  }
}
