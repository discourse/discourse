import { hash } from "rsvp";
import PreloadStore from "discourse/lib/preload-store";
import Badge from "discourse/models/badge";
import UserBadge from "discourse/models/user-badge";
import DiscourseRoute from "discourse/routes/discourse";

export default class BadgesShow extends DiscourseRoute {
  queryParams = {
    username: {
      refreshModel: true,
    },
  };

  serialize(model) {
    return model.getProperties("id", "slug");
  }

  model(params) {
    if (PreloadStore.get("badge")) {
      return PreloadStore.getAndRemove("badge").then((json) =>
        Badge.createFromJson(json)
      );
    } else {
      return Badge.findById(params.id);
    }
  }

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
  }

  titleToken() {
    const model = this.modelFor("badges.show");
    if (model) {
      return model.get("name");
    }
  }

  setupController(controller) {
    super.setupController(...arguments);
    controller.set("userBadges", this.userBadgesGrant);
    controller.set("userBadgesAll", this.userBadgesAll);
  }
}
