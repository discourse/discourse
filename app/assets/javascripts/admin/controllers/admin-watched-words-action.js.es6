import computed from "ember-addons/ember-computed-decorators";
import WatchedWord from "admin/models/watched-word";

export default Ember.Controller.extend({
  actionNameKey: null,
  adminWatchedWords: Ember.inject.controller(),
  showWordsList: Ember.computed.or(
    "adminWatchedWords.filtered",
    "adminWatchedWords.showWords"
  ),

  findAction(actionName) {
    return (this.get("adminWatchedWords.model") || []).findBy(
      "nameKey",
      actionName
    );
  },

  @computed("actionNameKey", "adminWatchedWords.model")
  filteredContent(actionNameKey) {
    if (!actionNameKey) {
      return [];
    }

    const a = this.findAction(actionNameKey);
    return a ? a.words : [];
  },

  @computed("actionNameKey")
  actionDescription(actionNameKey) {
    return I18n.t("admin.watched_words.action_descriptions." + actionNameKey);
  },

  @computed("actionNameKey", "adminWatchedWords.model")
  wordCount(actionNameKey) {
    const a = this.findAction(actionNameKey);
    return a ? a.words.length : 0;
  },

  actions: {
    recordAdded(arg) {
      const a = this.findAction(this.get("actionNameKey"));
      if (a) {
        a.words.unshiftObject(arg);
        a.incrementProperty("count");
        Em.run.schedule("afterRender", () => {
          // remove from other actions lists
          let match = null;
          this.get("adminWatchedWords.model").forEach(action => {
            if (match) return;

            if (action.nameKey !== this.get("actionNameKey")) {
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
      const a = this.findAction(this.get("actionNameKey"));
      if (a) {
        a.words.removeObject(arg);
        a.decrementProperty("count");
      }
    },

    uploadComplete() {
      WatchedWord.findAll().then(data => {
        this.set("adminWatchedWords.model", data);
      });
    }
  }
});
