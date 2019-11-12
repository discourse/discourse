import DiscourseRoute from "discourse/routes/discourse";
import User from "discourse/models/user";

export default DiscourseRoute.extend({
  titleToken() {
    const username = this.modelFor("user").username;
    if (username) {
      return [I18n.t("user.profile"), username];
    }
  },

  actions: {
    willTransition(transition) {
      // will reset the indexStream when transitioning to routes that aren't "indexStream"
      // otherwise the "header" will jump
      const isIndexStream = transition.targetName === "user.summary";
      this.controllerFor("user").set("indexStream", isIndexStream);
      return true;
    },

    undoRevokeApiKey(key) {
      key.undoRevoke();
    },

    revokeApiKey(key) {
      key.revoke();
    }
  },

  beforeModel() {
    if (this.siteSettings.hide_user_profiles_from_public && !this.currentUser) {
      this.replaceWith("discovery");
    }
  },

  model(params) {
    // If we're viewing the currently logged in user, return that object instead
    if (
      this.currentUser &&
      params.username.toLowerCase() === this.currentUser.username_lower
    ) {
      return this.currentUser;
    }

    return User.create({
      username: encodeURIComponent(params.username)
    });
  },

  afterModel() {
    const user = this.modelFor("user");

    return user
      .findDetails()
      .then(() => user.findStaffInfo())
      .catch(() => this.replaceWith("/404"));
  },

  serialize(model) {
    if (!model) return {};

    return { username: (model.username || "").toLowerCase() };
  },

  setupController(controller, user) {
    controller.set("model", user);
    this.searchService.set("searchContext", user.searchContext);
  },

  activate() {
    this._super(...arguments);

    const user = this.modelFor("user");
    this.messageBus.subscribe(`/u/${user.username_lower}`, data =>
      user.loadUserAction(data)
    );
  },

  deactivate() {
    this._super(...arguments);

    const user = this.modelFor("user");
    this.messageBus.unsubscribe(`/u/${user.username_lower}`);

    // Remove the search context
    this.searchService.set("searchContext", null);
  }
});
