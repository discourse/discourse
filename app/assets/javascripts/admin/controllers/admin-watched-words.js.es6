import { isEmpty } from "@ember/utils";
import { alias } from "@ember/object/computed";
import EmberObject from "@ember/object";
import Controller from "@ember/controller";
import discourseDebounce from "discourse/lib/debounce";
import { observes } from "discourse-common/utils/decorators";

export default Controller.extend({
  filter: null,
  filtered: false,
  showWords: false,
  disableShowWords: alias("filtered"),
  regularExpressions: null,

  filterContentNow() {
    if (!!isEmpty(this.allWatchedWords)) return;

    let filter;
    if (this.filter) {
      filter = this.filter.toLowerCase();
    }

    if (filter === undefined || filter.length < 1) {
      this.set("model", this.allWatchedWords);
      return;
    }

    const matchesByAction = [];

    this.allWatchedWords.forEach(wordsForAction => {
      const wordRecords = wordsForAction.words.filter(wordRecord => {
        return wordRecord.word.indexOf(filter) > -1;
      });
      matchesByAction.pushObject(
        EmberObject.create({
          nameKey: wordsForAction.nameKey,
          name: wordsForAction.name,
          words: wordRecords,
          count: wordRecords.length
        })
      );
    });

    this.set("model", matchesByAction);
  },

  @observes("filter")
  filterContent: discourseDebounce(function() {
    this.filterContentNow();
    this.set("filtered", !isEmpty(this.filter));
  }, 250),

  actions: {
    clearFilter() {
      this.setProperties({ filter: "" });
    },

    toggleMenu() {
      $(".admin-detail").toggleClass("mobile-closed mobile-open");
    }
  }
});
