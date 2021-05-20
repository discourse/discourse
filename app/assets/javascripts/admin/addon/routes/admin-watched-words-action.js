import DiscourseRoute from "discourse/routes/discourse";
import EmberObject from "@ember/object";
import I18n from "I18n";

export default DiscourseRoute.extend({
  model(params) {
    const controller = this.controllerFor("adminWatchedWordsAction");
    controller.set("actionNameKey", params.action_id);
    return EmberObject.create({
      nameKey: params.action_id,
      name: I18n.t("admin.watched_words.actions." + params.action_id),
      words: controller.filteredContent,
    });
  },
});
