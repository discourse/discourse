import Draft from "discourse/models/draft";

export default Discourse.Route.extend({
  titleToken() {
    const model = this.modelFor("user");
    const username = model.get("username");
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
    const currentUser = this.currentUser;
    if (
      currentUser &&
      params.username.toLowerCase() === currentUser.get("username_lower")
    ) {
      return currentUser;
    }

    return Discourse.User.create({ username: params.username });
  },

  afterModel() {
    const user = this.modelFor("user");
    const self = this;

    return user
      .findDetails()
      .then(function() {
        return user.findStaffInfo();
      })
      .catch(function() {
        return self.replaceWith("/404");
      });
  },

  serialize(model) {
    if (!model) return {};
    return { username: (Em.get(model, "username") || "").toLowerCase() };
  },

  setupController(controller, user) {
    controller.set("model", user);
    this.searchService.set("searchContext", user.get("searchContext"));

    const composerController = this.controllerFor("composer");
    controller.set("model", user);
    if (this.currentUser) {
      Draft.get("new_private_message").then(function(data) {
        if (data.draft) {
          composerController.open({
            draft: data.draft,
            draftKey: "new_private_message",
            ignoreIfChanged: true,
            draftSequence: data.draft_sequence
          });
        }
      });
    }
  },

  activate() {
    this._super();
    const user = this.modelFor("user");
    this.messageBus.subscribe("/u/" + user.get("username_lower"), function(
      data
    ) {
      user.loadUserAction(data);
    });
  },

  deactivate() {
    this._super();
    this.messageBus.unsubscribe(
      "/u/" + this.modelFor("user").get("username_lower")
    );

    // Remove the search context
    this.searchService.set("searchContext", null);
  }
});
