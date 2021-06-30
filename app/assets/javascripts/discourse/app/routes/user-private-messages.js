import Composer from "discourse/models/composer";
import Tag from "discourse/models/tag";
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
    const model = { user, tags: [] };

    if (this.site.can_tag_pms) {
      return ajax(`/tags/personal_messages/${user.username_lower}`, {
        data: { limit: this.siteSettings.max_tags_in_filter_list },
      })
        .then((result) => {
          model.tags = result.tags.map((tag) => Tag.create(tag));
          return model;
        })
        .catch((e) => {
          popupAjaxError(e);
          return model;
        });
    } else {
      return model;
    }
  },

  setupController(controller, model) {
    controller.setProperties({
      model: model.user,
      tags: model.tags,
    });

    if (this.currentUser) {
      const composerController = this.controllerFor("composer");

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
