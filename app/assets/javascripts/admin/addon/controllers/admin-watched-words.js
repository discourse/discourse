import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { observes } from "@ember-decorators/object";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";

export default class AdminWatchedWordsController extends Controller {
  filter = null;
  showWords = false;

  _filterContent() {
    if (isEmpty(this.allWatchedWords)) {
      return;
    }

    if (!this.filter) {
      this.set("model", this.allWatchedWords);
      return;
    }

    const filter = this.filter.toLowerCase();
    const model = [];

    this.allWatchedWords.forEach((wordsForAction) => {
      const wordRecords = wordsForAction.words.filter((wordRecord) => {
        return wordRecord.word.includes(filter);
      });

      model.pushObject(
        EmberObject.create({
          nameKey: wordsForAction.nameKey,
          name: wordsForAction.name,
          words: wordRecords,
        })
      );
    });
    this.set("model", model);
  }

  @observes("filter")
  filterContent() {
    discourseDebounce(this, this._filterContent, INPUT_DELAY);
  }

  @action
  clearFilter() {
    this.set("filter", "");
  }

  @action
  toggleMenu() {
    const adminDetail = document.querySelector(".admin-detail");
    ["mobile-closed", "mobile-open"].forEach((state) => {
      adminDetail.classList.toggle(state);
    });
  }
}
