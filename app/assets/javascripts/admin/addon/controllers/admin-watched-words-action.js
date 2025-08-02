import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { or } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { fmt } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import WatchedWordTestingModal from "admin/components/modal/watched-word-testing";
import WatchedWord from "admin/models/watched-word";

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
        return i18n("admin.watched_words.invalid_regex", { word });
      }
    }
  }

  @discourseComputed("actionNameKey")
  actionDescription(actionNameKey) {
    return i18n(`admin.watched_words.action_descriptions.${actionNameKey}`);
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
      for (const otherAction of this.adminWatchedWords.model) {
        if (otherAction.nameKey === this.actionNameKey) {
          continue;
        }

        const match = otherAction.words.findBy("id", arg.id);
        if (match) {
          otherAction.words.removeObject(match);
          break;
        }
      }
    });
  }

  @action
  recordRemoved(arg) {
    this.currentAction?.words.removeObject(arg);
  }

  @action
  async uploadComplete() {
    const data = await WatchedWord.findAll();
    this.adminWatchedWords.set("model", data);
  }

  @action
  async test() {
    const data = await WatchedWord.findAll();
    this.adminWatchedWords.set("model", data);
    this.modal.show(WatchedWordTestingModal, {
      model: { watchedWord: this.currentAction },
    });
  }

  @action
  clearAll() {
    const actionKey = this.actionNameKey;
    this.dialog.yesNoConfirm({
      message: i18n("admin.watched_words.clear_all_confirm", {
        action: i18n(`admin.watched_words.actions.${actionKey}`),
      }),
      didConfirm: async () => {
        await ajax(`/admin/customize/watched_words/action/${actionKey}.json`, {
          type: "DELETE",
        });

        this.findAction(actionKey)?.set("words", []);
      },
    });
  }
}
