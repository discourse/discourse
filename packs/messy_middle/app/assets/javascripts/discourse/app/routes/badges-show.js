import Badge from "discourse/models/badge";
import DiscourseRoute from "discourse/routes/discourse";
import PreloadStore from "discourse/lib/preload-store";
import UserBadge from "discourse/models/user-badge";
import { scrollTop } from "discourse/mixins/scroll-top";
import { hash } from "rsvp";
import { action } from "@ember/object";

export default DiscourseRoute.extend({
  queryParams: {
    username: {
      refreshModel: true,
    },
  },

  serialize(model) {
    return model.getProperties("id", "slug");
  },

  model(params) {
    if (PreloadStore.get("badge")) {
      return PreloadStore.getAndRemove("badge").then((json) =>
        Badge.createFromJson(json)
      );
    } else {
      return Badge.findById(params.id);
    }
  },

  afterModel(model, transition) {
    const usernameFromParams =
      transition.to.queryParams && transition.to.queryParams.username;

    const userBadgesGrant = UserBadge.findByBadgeId(model.get("id"), {
      username: usernameFromParams,
    }).then((userBadges) => {
      this.userBadgesGrant = userBadges;
    });

    const username = this.currentUser && this.currentUser.username_lower;
    const userBadgesAll = UserBadge.findByUsername(username).then(
      (userBadges) => {
        this.userBadgesAll = userBadges;
      }
    );

    const promises = {
      userBadgesGrant,
      userBadgesAll,
    };

    return hash(promises);
  },

  titleToken() {
    const model = this.modelFor("badges.show");
    if (model) {
      return model.get("name");
    }
  },

  setupController(controller, model) {
    controller.set("model", model);
    controller.set("userBadges", this.userBadgesGrant);
    controller.set("userBadgesAll", this.userBadgesAll);
  },

  @action
  didTransition() {
    this.controllerFor("badges/show")._showFooter();
    scrollTop();
    return true;
  },
});
