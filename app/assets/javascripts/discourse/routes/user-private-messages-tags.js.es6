import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default DiscourseRoute.extend({
  model() {
    const username = this.modelFor("user").get("username_lower");
    return ajax(`/tags/personal_messages/${username}`)
      .then(result => {
        return result.tags.map(tag => Ember.Object.create(tag));
      })
      .catch(popupAjaxError);
  },

  titleToken() {
    return [I18n.t("tagging.tags"), I18n.t("user.private_messages")];
  },

  setupController(controller, model) {
    this.controllerFor("user-private-messages-tags").setProperties({
      model,
      sortProperties: this.siteSettings.tags_sort_alphabetically
        ? ["id"]
        : ["count:desc", "id"],
      tagsForUser: this.modelFor("user").get("username_lower")
    });
    this.controllerFor("user-private-messages").setProperties({
      showToggleBulkSelect: false,
      pmView: "tags"
    });
  }
});
