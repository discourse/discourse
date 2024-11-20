import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { findOrResetCachedTopicList } from "discourse/lib/cached-topic-list";
import UserAction from "discourse/models/user-action";
import UserTopicListRoute from "discourse/routes/user-topic-list";
import getURL from "discourse-common/lib/get-url";
import { iconHTML } from "discourse-common/lib/icon-library";
import { i18n } from "discourse-i18n";

export const NEW_FILTER = "new";
export const UNREAD_FILTER = "unread";
export const INBOX_FILTER = "inbox";
export const ARCHIVE_FILTER = "archive";

// A helper to build a user topic list route
export default (inboxType, path, filter) => {
  return class BuildPrivateMessagesRoute extends UserTopicListRoute {
    userActionType = UserAction.TYPES.messages_received;

    titleToken() {
      return [i18n(`user.messages.${filter}`), i18n("user.private_messages")];
    }

    async model(params = {}) {
      const topicListFilter = `topics/${path}/${this.modelFor("user").get(
        "username_lower"
      )}`;

      const lastTopicList = findOrResetCachedTopicList(
        this.session,
        topicListFilter
      );

      if (lastTopicList) {
        return lastTopicList;
      }

      const model = await this.store.findFiltered("topicList", {
        filter: topicListFilter,
        params,
      });

      // andrei: we agreed that this is an anti pattern,
      // it's better to avoid mutating a rest model like this
      // this place we'll be refactored later
      // see https://github.com/discourse/discourse/pull/14313#discussion_r708784704
      model.set("emptyState", this.emptyState());
      return model;
    }

    setupController() {
      super.setupController(...arguments);

      const userPrivateMessagesController = this.controllerFor(
        "user-private-messages"
      );

      const userTopicsListController = this.controllerFor("user-topics-list");

      userTopicsListController.setProperties({
        hideCategory: true,
        showPosters: true,
        tagsForUser: this.modelFor("user").get("username_lower"),
        showToggleBulkSelect: true,
        filter,
        group: null,
        inbox: inboxType,
      });

      let ascending = userTopicsListController.ascending;
      if (ascending === "true") {
        ascending = true;
      } else if (ascending === "false") {
        ascending = false;
      }
      userTopicsListController.setProperties({
        ascending,
      });

      userTopicsListController.bulkSelectHelper.clear();

      userTopicsListController.subscribe();

      userPrivateMessagesController.setProperties({
        archive: false,
        group: null,
      });

      // Private messages don't have a unique search context instead
      // it is built upon the user search context and then tweaks the `type`.
      // Since this is the only model in which we set a custom `type` we don't
      // want to create a stand-alone `setSearchType` on the search service so
      // we can instead explicitly set the search context and pass in the `type`
      const pmSearchContext = {
        ...this.controllerFor("user").get("model.searchContext"),
        type: "private_messages",
      };
      this.searchService.searchContext = pmSearchContext;
    }

    emptyState() {
      const title = i18n("user.no_messages_title");
      const body = this.currentUser?.can_send_private_messages
        ? htmlSafe(
            i18n("user.no_messages_body", {
              aboutUrl: getURL("/about"),
              icon: iconHTML("envelope"),
            })
          )
        : "";
      return { title, body };
    }

    deactivate() {
      this.controllerFor("user-topics-list").unsubscribe();

      this.searchService.searchContext = this.controllerFor("user").get(
        "model.searchContext"
      );
    }

    dismissReadOptions() {
      return {};
    }

    @action
    dismissReadTopics(dismissTopics) {
      const operationType = dismissTopics ? "topics" : "posts";
      const controller = this.controllerFor("user-topics-list");

      controller.send("dismissRead", operationType, {
        private_message_inbox: inboxType,
        ...this.dismissReadOptions(),
      });
    }
  };
};
