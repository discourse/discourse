import I18n from "I18n";
import UserAction from "discourse/models/user-action";
import UserTopicListRoute from "discourse/routes/user-topic-list";
import { findOrResetCachedTopicList } from "discourse/lib/cached-topic-list";
import { action } from "@ember/object";

export const NEW_FILTER = "new";
export const UNREAD_FILTER = "unread";
export const INBOX_FILTER = "inbox";
export const ARCHIVE_FILTER = "archive";

// A helper to build a user topic list route
export default (inboxType, path, filter) => {
  return UserTopicListRoute.extend({
    userActionType: UserAction.TYPES.messages_received,

    titleToken() {
      return [
        I18n.t(`user.messages.${filter}`),
        I18n.t("user.private_messages"),
      ];
    },

    @action
    didTransition() {
      this.controllerFor("user-topics-list")._showFooter();
      return true;
    },

    model() {
      const topicListFilter =
        "topics/" + path + "/" + this.modelFor("user").get("username_lower");

      const lastTopicList = findOrResetCachedTopicList(
        this.session,
        topicListFilter
      );

      return lastTopicList
        ? lastTopicList
        : this.store.findFiltered("topicList", { filter: topicListFilter });
    },

    setupController() {
      this._super.apply(this, arguments);

      const userPrivateMessagesController = this.controllerFor(
        "user-private-messages"
      );

      const userTopicsListController = this.controllerFor("user-topics-list");

      userTopicsListController.setProperties({
        hideCategory: true,
        showPosters: true,
        tagsForUser: this.modelFor("user").get("username_lower"),
        selected: [],
        showToggleBulkSelect: true,
        filter: filter,
        group: null,
        inbox: inboxType,
        pmTopicTrackingState:
          userPrivateMessagesController.pmTopicTrackingState,
      });

      userTopicsListController.subscribe();

      userPrivateMessagesController.setProperties({
        archive: false,
        pmView: inboxType,
        group: null,
      });

      this.searchService.set("contextType", "private_messages");
    },

    deactivate() {
      this.controllerFor("user-topics-list").unsubscribe();

      this.searchService.set(
        "searchContext",
        this.controllerFor("user").get("model.searchContext")
      );
    },

    dismissReadOptions() {
      return {};
    },

    @action
    dismissReadTopics(dismissTopics) {
      const operationType = dismissTopics ? "topics" : "posts";
      const controller = this.controllerFor("user-topics-list");

      controller.send("dismissRead", operationType, {
        private_message_inbox: inboxType,
        ...this.dismissReadOptions(),
      });
    },
  });
};
