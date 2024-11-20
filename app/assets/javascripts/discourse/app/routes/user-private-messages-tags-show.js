import createPMRoute from "discourse/routes/build-private-messages-route";
import { i18n } from "discourse-i18n";

export default class extends createPMRoute("tags", "private-messages-tags") {
  titleToken() {
    return [
      this.get("tagId"),
      i18n("tagging.tags"),
      i18n("user.private_messages"),
    ];
  }

  model(params) {
    this.controllerFor("user-private-messages").set("tagId", params.id);
    this.controllerFor("user-private-messages-tags").set("tagName", params.id);

    const username = this.modelFor("user").get("username_lower");
    this.set("tagId", params.id);

    return this.store.findFiltered("topicList", {
      filter: `topics/private-messages-tags/${username}/${params.id}`,
    });
  }
}
