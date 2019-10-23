import createPMRoute from "discourse/routes/build-private-messages-route";
import { findOrResetCachedTopicList } from "discourse/lib/cached-topic-list";

export default createPMRoute("groups", "private-messages-groups").extend({
  groupName: null,

  titleToken() {
    const groupName = this.groupName;

    if (groupName) {
      return [
        `${groupName.capitalize()} ${I18n.t("user.messages.archive")}`,
        I18n.t("user.private_messages")
      ];
    }
  },

  model(params) {
    const username = this.modelFor("user").get("username_lower");
    const filter =
      `topics/private-messages-group/${username}/${params.name}/archive`;
    const lastTopicList = findOrResetCachedTopicList(this.session, filter);
    return lastTopicList ? lastTopicList : this.store.findFiltered("topicList", { filter });
  },

  afterModel(model) {
    const split = model.get("filter").split("/");
    const groupName = split[split.length - 2];
    this.set("groupName", groupName);
    const groups = this.modelFor("user").get("groups");
    const group = _.first(groups.filterBy("name", groupName));
    this.controllerFor("user-private-messages").set("group", group);
  },

  setupController(controller, model) {
    this._super.apply(this, arguments);
    const split = model.get("filter").split("/");
    const group = split[split.length - 2];
    this.controllerFor("user-private-messages").set("groupFilter", group);
    this.controllerFor("user-private-messages").set("archive", true);
    this.controllerFor("user-topics-list").subscribe(
      `/private-messages/group/${group}/archive`
    );
  }
});
