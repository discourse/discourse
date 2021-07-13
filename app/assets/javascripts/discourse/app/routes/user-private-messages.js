import EmberObject from "@ember/object";
import Composer from "discourse/models/composer";
import DiscourseRoute from "discourse/routes/discourse";
import Draft from "discourse/models/draft";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default DiscourseRoute.extend({
  queryParams: {
    tag: {
      refreshModel: true,
    },
  },

  renderTemplate() {
    this.render("user/messages");
  },

  model() {
    const user = this.modelFor("user");

    return ajax(`/tags/personal_messages/${user.username_lower}`)
      .then((result) => {
        return {
          user,
          tags: result.tags.map((tag) => EmberObject.create(tag)),
        };
      })
      .catch(popupAjaxError);
  },

  setupController(controller, model) {
    const composerController = this.controllerFor("composer");

    controller.setProperties({
      model: model.user,
      tags: model.tags,
    });

    if (this.currentUser) {
      Draft.get("new_private_message").then((data) => {
        if (data.draft) {
          composerController.open({
            draft: data.draft,
            draftKey: Composer.NEW_PRIVATE_MESSAGE_KEY,
            ignoreIfChanged: true,
            draftSequence: data.draft_sequence,
          });
        }
      });
    }
  },

  actions: {
    refresh() {
      this.refresh();
    },

    willTransition: function () {
      this._super(...arguments);
      this.controllerFor("user").set("pmView", null);
      return true;
    },
  },
});
