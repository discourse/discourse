import DiscourseRoute from "discourse/routes/discourse";
import UserBadge from "discourse/models/user-badge";
import Badge from "discourse/models/badge";
import PreloadStore from "preload-store";

export default DiscourseRoute.extend({
  queryParams: {
    username: {
      refreshModel: true
    }
  },
  actions: {
    didTransition() {
      this.controllerFor("badges/show")._showFooter();
      return true;
    }
  },

  serialize(model) {
    return model.getProperties("id", "slug");
  },

  model(params) {
    if (PreloadStore.get("badge")) {
      return PreloadStore.getAndRemove("badge").then(json =>
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
      username: usernameFromParams
    }).then(userBadges => {
      this.userBadgesGrant = userBadges;
    });

    const username = this.currentUser && this.currentUser.username_lower;
    const userBadgesAll = UserBadge.findByUsername(username).then(
      userBadges => {
        this.userBadgesAll = userBadges;
      }
    );

    const promises = {
      userBadgesGrant,
      userBadgesAll
    };

    return Ember.RSVP.hash(promises);
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
  }
});
