import EmberObject from "@ember/object";
import Controller from "@ember/controller";
import debounce from "discourse/lib/debounce";

export default Controller.extend({
  filter: null,
  filtered: false,
  showWords: false,
  disableShowWords: Ember.computed.alias("filtered"),
  regularExpressions: null,

  filterContentNow() {
    if (!!Ember.isEmpty(this.allWatchedWords)) return;

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

  filterContent: debounce(function() {
    this.filterContentNow();
    this.set("filtered", !Ember.isEmpty(this.filter));
  }, 250).observes("filter"),

  actions: {
    clearFilter() {
      this.setProperties({ filter: "" });
    },

    toggleMenu() {
      $(".admin-detail").toggleClass("mobile-closed mobile-open");
    }
  }
});
