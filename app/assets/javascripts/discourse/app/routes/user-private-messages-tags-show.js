import createPMRoute from "discourse/routes/build-private-messages-route";
import I18n from "I18n";

export default createPMRoute("tags", "private-messages-tags").extend({
  titleToken() {
    return [
      this.get("tagId"),
      I18n.t("tagging.tags"),
      I18n.t("user.private_messages"),
    ];
  },

  model(params) {
    this.controllerFor("user-private-messages").set("tagId", params.id);
    this.controllerFor("user-private-messages-tags").set("tagName", params.id);

    const username = this.modelFor("user").get("username_lower");
    this.set("tagId", params.id);

    return this.store.findFiltered("topicList", {
      filter: `topics/private-messages-tags/${username}/${params.id}`,
    });
  },
});
