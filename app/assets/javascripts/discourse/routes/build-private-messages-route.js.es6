import UserTopicListRoute from "discourse/routes/user-topic-list";

// A helper to build a user topic list route
export default (viewName, path) => {
  return UserTopicListRoute.extend({
    userActionType: Discourse.UserAction.TYPES.messages_received,

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
      this.searchService.set('contextType', 'private_messages');
    }
  });
};
