import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { observes } from "@ember-decorators/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import { trackedArray } from "discourse/lib/tracked-tools";
import WatchedWord from "admin/models/watched-word";

const MESSAGE_BUS_UPLOAD_PATH = "/watched_words/upload";

export default class AdminWatchedWordsController extends Controller {
  @service messageBus;

  @tracked filter = null;
  @trackedArray allWatchedWords;
  @trackedArray filteredWatchedWords;

  showWords = false;

  @observes("allWatchedWords", "filter")
  filterContent() {
    discourseDebounce(this, this.updateFilteredContent, INPUT_DELAY);
  }

  @bind
  subscribe() {
    this.messageBus.subscribe(MESSAGE_BUS_UPLOAD_PATH, this._onUploadMessage);
  }

  @bind
  unsubscribe() {
    this.messageBus.unsubscribe(MESSAGE_BUS_UPLOAD_PATH, this._onUploadMessage);
  }

  @bind
  async updateAllWords() {
    this.allWatchedWords = await WatchedWord.findAll();
    this.filterContent();
  }

  @bind
  updateFilteredContent() {
    if (isEmpty(this.allWatchedWords)) {
      return;
    }

    if (!this.filter) {
      this.filteredWatchedWords = this.allWatchedWords;
      return;
    }

    const filter = this.filter.toLowerCase();
    const filteredWatchedWords = [];

    this.allWatchedWords.forEach((wordsForAction) => {
      const wordRecords = wordsForAction.words.filter((wordRecord) => {
        return wordRecord.word.includes(filter);
      });

      filteredWatchedWords.push(
        EmberObject.create({
          nameKey: wordsForAction.nameKey,
          name: wordsForAction.name,
          words: new TrackedArray(wordRecords),
        })
      );
    });

    this.filteredWatchedWords = filteredWatchedWords;
  }

  @bind
  async _onUploadMessage(message) {
    if (message.words_updated > 0) {
      await this.updateAllWords();
    }

    if (message.errors?.length) {
      popupAjaxError(message.errors[0]);
    }
  }

  @action
  clearFilter() {
    this.filter = "";
  }

  @action
  toggleMenu() {
    const adminDetail = document.querySelector(".admin-detail");
    ["mobile-closed", "mobile-open"].forEach((state) => {
      adminDetail.classList.toggle(state);
    });
  }
}
