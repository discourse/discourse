import debounce from "discourse/lib/debounce";

export default Ember.Controller.extend({
  filter: null,
  filtered: false,
  showWords: false,
  disableShowWords: Ember.computed.alias("filtered"),
  regularExpressions: null,

  filterContentNow() {
    if (!!Ember.isEmpty(this.get("allWatchedWords"))) return;

    let filter;
    if (this.get("filter")) {
      filter = this.get("filter").toLowerCase();
    }

    if (filter === undefined || filter.length < 1) {
      this.set("model", this.get("allWatchedWords"));
      return;
    }

    const matchesByAction = [];

    this.get("allWatchedWords").forEach(wordsForAction => {
      const wordRecords = wordsForAction.words.filter(wordRecord => {
        return wordRecord.word.indexOf(filter) > -1;
      });
      matchesByAction.pushObject(
        Ember.Object.create({
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
    this.set("filtered", !Ember.isEmpty(this.get("filter")));
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
