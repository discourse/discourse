import UserBadge from 'discourse/models/user-badge';
import Badge from 'discourse/models/badge';
import PreloadStore from 'preload-store';

export default Discourse.Route.extend({
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
    return model.getProperties('id', 'slug');
  },

  model(params) {
    let originalModel;
    if (PreloadStore.get("badge")) {
      originalModel = PreloadStore.getAndRemove("badge").then(json => Badge.createFromJson(json));
    } else {
      originalModel = Badge.findById(params.id);
    };
    let userBadgeModel = UserBadge.findByUsername(this.modelFor('user').get('username'));

    const promises = {
      originalModel: originalModel,
      userBadgeModel: userBadgeModel
    }

    return rsvp.hash(promises);
    /*
    if (PreloadStore.get("badge")) {
      return PreloadStore.getAndRemove("badge").then(json => Badge.createFromJson(json));
    } else {
      return Badge.findById(params.id);
    }
    */
  },

  afterModel(model, transition) {
    const username = transition.queryParams && transition.queryParams.username;

    return UserBadge.findByBadgeId(model.get("id"), {username}).then(userBadges => {
      this.userBadges = userBadges;
    });
  },

  titleToken() {
    const model = this.modelFor("badges.show");
    if (model) {
      return model.get("name");
    }
  },

  setupController(controller, model) {
    controller.set("model", model.originalModel);
    controller.set("userBadgeModel", model.userBadgeModel);
    controller.set("userBadges", this.userBadges);
  }
});
