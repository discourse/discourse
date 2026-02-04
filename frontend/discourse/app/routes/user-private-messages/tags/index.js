import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class UserPrivateMessagesTagsIndex extends DiscourseRoute {
  model() {
    const username = this.modelFor("user").get("username_lower");

    return ajax(`/tags/personal_messages/${username}`)
      .then((result) => {
        return result.tags.map((tag) => EmberObject.create(tag));
      })
      .catch(popupAjaxError);
  }

  titleToken() {
    return [i18n("tagging.tags"), i18n("user.private_messages")];
  }

  setupController(controller, model) {
    const sortProperties = this.siteSettings.tags_sort_alphabetically
      ? ["name"]
      : ["count:desc", "name"];

    const tagsForUser = this.modelFor("user").get("username_lower");

    controller.setProperties({
      model,
      sortProperties,
      tagsForUser,
    });

    this.controllerFor("user-topics-list").set("showToggleBulkSelect", false);
    this.controllerFor("user-topics-list").bulkSelectHelper.clear();
  }
}
