import { ajax } from "discourse/lib/ajax";
import EmberObject from "@ember/object";

const WatchedWord = EmberObject.extend({
  save() {
    return ajax(
      "/admin/logs/watched_words" + (this.id ? "/" + this.id : "") + ".json",
      {
        type: this.id ? "PUT" : "POST",
        data: { word: this.word, action_key: this.action },
        dataType: "json"
      }
    );
  },

  destroy() {
    return ajax("/admin/logs/watched_words/" + this.id + ".json", {
      type: "DELETE"
    });
  }
});

WatchedWord.reopenClass({
  findAll() {
    return ajax("/admin/logs/watched_words.json").then(list => {
      const actions = {};
      list.words.forEach(s => {
        if (!actions[s.action]) {
          actions[s.action] = [];
        }
        actions[s.action].pushObject(WatchedWord.create(s));
      });

      list.actions.forEach(a => {
        if (!actions[a]) {
          actions[a] = [];
        }
      });

      return Object.keys(actions).map(n => {
        return EmberObject.create({
          nameKey: n,
          name: I18n.t("admin.watched_words.actions." + n),
          words: actions[n],
          count: actions[n].length,
          regularExpressions: list.regular_expressions,
          compiledRegularExpression: list.compiled_regular_expressions[n]
        });
      });
    });
  }
});

export default WatchedWord;
