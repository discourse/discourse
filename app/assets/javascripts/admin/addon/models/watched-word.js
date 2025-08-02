import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class WatchedWord extends EmberObject {
  static findAll() {
    return ajax("/admin/customize/watched_words.json").then((list) => {
      const actions = {};

      list.actions.forEach((action) => {
        actions[action] = [];
      });

      list.words.forEach((watchedWord) => {
        actions[watchedWord.action].pushObject(WatchedWord.create(watchedWord));
      });

      return Object.keys(actions).map((nameKey) => {
        return EmberObject.create({
          nameKey,
          name: i18n("admin.watched_words.actions." + nameKey),
          words: actions[nameKey],
          compiledRegularExpression: list.compiled_regular_expressions[nameKey],
        });
      });
    });
  }

  save() {
    return ajax(
      "/admin/customize/watched_words" +
        (this.id ? "/" + this.id : "") +
        ".json",
      {
        type: this.id ? "PUT" : "POST",
        data: {
          words: this.words,
          replacement: this.replacement,
          action_key: this.action,
          case_sensitive: this.isCaseSensitive,
          html: this.isHtml,
        },
        dataType: "json",
      }
    );
  }

  destroy() {
    return ajax("/admin/customize/watched_words/" + this.id + ".json", {
      type: "DELETE",
    });
  }
}
