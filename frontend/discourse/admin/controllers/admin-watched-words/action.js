import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { or } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import WatchedWordTestingModal from "discourse/admin/components/modal/watched-word-testing";
import { ajax } from "discourse/lib/ajax";
import { fmt } from "discourse/lib/computed";
import { i18n } from "discourse-i18n";

export default class AdminWatchedWordsActionController extends Controller {
  @service dialog;
  @service modal;
  @controller adminWatchedWords;

  @tracked actionNameKey = null;

  @fmt("actionNameKey", "/admin/customize/watched_words/action/%@/download")
  downloadLink;

  @or("adminWatchedWords.showWords", "adminWatchedWords.filter")
  showWordsList;

  get currentAction() {
    return this.adminWatchedWords.allWatchedWords.find(
      (item) => item.nameKey === this.actionNameKey
    );
  }

  get currentActionFiltered() {
    return this.adminWatchedWords.filteredWatchedWords.find(
      (item) => item.nameKey === this.actionNameKey
    );
  }

  get regexpError() {
    for (const { regexp, word } of this.currentAction.words) {
      try {
        RegExp(regexp);
      } catch {
        return i18n("admin.watched_words.invalid_regex", { word });
      }
    }
  }

  get actionDescription() {
    return i18n(
      `admin.watched_words.action_descriptions.${this.actionNameKey}`
    );
  }

  @action
  recordAdded(arg) {
    const currentAction = this.currentAction;
    if (!currentAction) {
      return;
    }

    currentAction.words.unshift(arg);
    schedule("afterRender", () => {
      // remove from other actions lists
      for (const otherAction of this.adminWatchedWords.filteredWatchedWords) {
        if (otherAction.nameKey === this.actionNameKey) {
          continue;
        }

        const matchIndex = otherAction.words.findIndex((w) => w.id === arg.id);
        if (matchIndex !== -1) {
          otherAction.words.splice(matchIndex, 1);
          break;
        }
      }

      this.adminWatchedWords.updateFilteredContent();
    });
  }

  @action
  recordRemoved(arg) {
    if (this.currentAction) {
      const matchIndex = this.currentAction.words.findIndex(
        (w) => w.id === arg.id
      );
      if (matchIndex !== -1) {
        this.currentAction.words.splice(matchIndex, 1);
      }
    }

    this.adminWatchedWords.updateFilteredContent();
  }

  @action
  async uploadComplete() {
    return this.adminWatchedWords.updateAllWords();
  }

  @action
  async test() {
    await this.adminWatchedWords.updateAllWords();
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

        const currentAction = this.currentAction;
        if (currentAction) {
          currentAction.words.length = 0;
          this.adminWatchedWords.updateFilteredContent();
        }
      },
    });
  }
}
