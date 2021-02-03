import DiscourseRoute from "discourse/routes/discourse";
import EmberObject from "@ember/object";
import I18n from "I18n";

export default DiscourseRoute.extend({
  model(params) {
    this.controllerFor("adminWatchedWordsAction").set(
      "actionNameKey",
      params.action_id
    );
    let filteredContent = this.controllerFor("adminWatchedWordsAction").get(
      "filteredContent"
    );
    return EmberObject.create({
      nameKey: params.action_id,
      name: I18n.t("admin.watched_words.actions." + params.action_id),
      words: filteredContent,
    });
  },
});
