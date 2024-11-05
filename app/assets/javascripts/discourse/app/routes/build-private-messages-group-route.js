import { getOwner } from "@ember/owner";
import { capitalize } from "@ember/string";
import { findOrResetCachedTopicList } from "discourse/lib/cached-topic-list";
import createPMRoute from "discourse/routes/build-private-messages-route";
import I18n from "discourse-i18n";

export default (inboxType, filter) => {
  return class extends createPMRoute(
    inboxType,
    "private-messages-groups",
    filter
  ) {
    groupName = null;

    titleToken() {
      const groupName = this.groupName;

      if (groupName) {
        let title = capitalize(groupName);

        if (filter !== "inbox") {
          title = `${title} ${I18n.t("user.messages." + filter)}`;
        }

        return [title, I18n.t(`user.private_messages`)];
      }
    }

    async model(params = {}) {
      const username = this.modelFor("user").get("username_lower");
      const groupName = this.modelFor("userPrivateMessages.group").name;

      let topicListFilter = `topics/private-messages-group/${username}/${groupName}`;

      if (filter !== "inbox") {
        topicListFilter = `${topicListFilter}/${filter}`;
      }

      const lastTopicList = findOrResetCachedTopicList(
        this.session,
        topicListFilter
      );

      if (lastTopicList) {
        return lastTopicList;
      }

      const topicList = await this.store.findFiltered("topicList", {
        filter: topicListFilter,
        params,
      });

      // andrei: we agreed that this is an anti pattern,
      // it's better to avoid mutating a rest model like this
      // this place we'll be refactored later
      // see https://github.com/discourse/discourse/pull/14313#discussion_r708784704
      topicList.set("emptyState", this.emptyState());
      return topicList;
    }

    afterModel(model) {
      const filters = model.get("filter").split("/");
      let groupName;

      if (filter !== "inbox") {
        groupName = filters[filters.length - 2];
      } else {
        groupName = filters.pop();
      }

      const group = this.modelFor("userPrivateMessages.group");

      this.setProperties({ groupName, group });
    }

    setupController() {
      super.setupController(...arguments);

      const userTopicsListController = this.controllerFor("user-topics-list");
      userTopicsListController.set("group", this.group);

      const pmTopicTrackingState = getOwner(this).lookup(
        "service:pm-topic-tracking-state"
      );
      pmTopicTrackingState.activeGroup = this.group;

      this.controllerFor("user-private-messages").set("group", this.group);
    }

    emptyState() {
      return {
        title: I18n.t("user.no_messages_title"),
        body: "",
      };
    }

    dismissReadOptions() {
      return {
        group_name: this.get("groupName"),
      };
    }
  };
};
