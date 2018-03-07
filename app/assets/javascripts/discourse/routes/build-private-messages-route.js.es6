import UserTopicListRoute from "discourse/routes/user-topic-list";

// A helper to build a user topic list route
export default (viewName, path, channel) => {
  return UserTopicListRoute.extend({
    userActionType: Discourse.UserAction.TYPES.messages_received,

    titleToken() {
      const key = viewName === "index" ? "inbox" : viewName;
      return [I18n.t(`user.messages.${key}`), I18n.t("user.private_messages")];
    },

    actions: {
      didTransition() {
        this.controllerFor("user-topics-list")._showFooter();
        return true;
      }
    },

    model() {
      return this.store.findFiltered("topicList", { filter: "topics/" + path + "/" + this.modelFor("user").get("username_lower") });
    },

    setupController() {
      this._super.apply(this, arguments);

      if (channel) {
        this.controllerFor("user-topics-list").subscribe(`/private-messages/${channel}`);
      }

      this.controllerFor("user-topics-list").setProperties({
        hideCategory: true,
        showPosters: true,
        canBulkSelect: true,
        selected: []
      });

      this.controllerFor("user-private-messages").set("archive", false);
      this.controllerFor("user-private-messages").set("pmView", viewName);
      this.searchService.set('contextType', 'private_messages');
    },

    deactivate() {
      this.controllerFor('user-topics-list').unsubscribe();

      this.searchService.set(
        'searchContext',
        this.controllerFor("user").get("model.searchContext")
      );
    }
  });
};
