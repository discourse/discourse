import I18n from "I18n";
import createPMRoute from "discourse/routes/build-private-messages-route";
import { findOrResetCachedTopicList } from "discourse/lib/cached-topic-list";

export default (viewName, channel) => {
  return createPMRoute("groups", "private-messages-groups").extend({
    groupName: null,

    titleToken() {
      const groupName = this.groupName;

      if (groupName) {
        let title = groupName.capitalize();

        if (viewName !== "index") {
          title = `${title} ${I18n.t("user.messages." + viewName)}`;
        }

        return [title, I18n.t(`user.private_messages`)];
      }
    },

    model(params) {
      const username = this.modelFor("user").get("username_lower");
      let filter = `topics/private-messages-group/${username}/${params.name}`;

      if (viewName !== "index") {
        filter = `${filter}/${viewName}`;
      }

      const lastTopicList = findOrResetCachedTopicList(this.session, filter);

      return lastTopicList
        ? lastTopicList
        : this.store.findFiltered("topicList", { filter });
    },

    afterModel(model) {
      const filters = model.get("filter").split("/");
      let groupName;

      if (viewName !== "index") {
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
      this.controllerFor("user-private-messages").set("group", this.group);

      if (channel) {
        this.controllerFor("user-topics-list").subscribe(
          `/private-messages/group/${this.get(
            "groupName"
          ).toLowerCase()}/${channel}`
        );
      }
    },
  });
};
