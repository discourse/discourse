import I18n from "I18n";
import createPMRoute from "discourse/routes/build-private-messages-route";
import { findOrResetCachedTopicList } from "discourse/lib/cached-topic-list";

export default (inboxType, filter) => {
  return createPMRoute(inboxType, "private-messages-groups", filter).extend({
    groupName: null,

    titleToken() {
      const groupName = this.groupName;

      if (groupName) {
        let title = groupName.capitalize();

        if (filter !== "inbox") {
          title = `${title} ${I18n.t("user.messages." + filter)}`;
        }

        return [title, I18n.t(`user.private_messages`)];
      }
    },

    model(params) {
      const username = this.modelFor("user").get("username_lower");
      let topicListFilter = `topics/private-messages-group/${username}/${params.name}`;

      if (filter !== "inbox") {
        topicListFilter = `${topicListFilter}/${filter}`;
      }

      const lastTopicList = findOrResetCachedTopicList(
        this.session,
        topicListFilter
      );

      return lastTopicList
        ? lastTopicList
        : this.store.findFiltered("topicList", { filter: topicListFilter });
    },

    afterModel(model) {
      const filters = model.get("filter").split("/");
      let groupName;

      if (filter !== "inbox") {
        groupName = filters[filters.length - 2];
      } else {
        groupName = filters.pop();
      }

      const group = this.modelFor("user")
        .get("groups")
        .filterBy("name", groupName)[0];

      this.setProperties({ groupName: groupName, group });
    },

    setupController() {
      this._super.apply(this, arguments);

      const userTopicsListController = this.controllerFor("user-topics-list");
      userTopicsListController.set("group", this.group);

      userTopicsListController.set(
        "pmTopicTrackingState.activeGroup",
        this.group
      );

      this.controllerFor("user-private-messages").set("group", this.group);
    },

    dismissReadOptions() {
      return {
        group_name: this.get("groupName"),
      };
    },
  });
};
