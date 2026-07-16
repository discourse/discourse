import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class TopicZoomRoute extends DiscourseRoute {
  @service embeddableChat;
  @service store;

  activate() {
    this.embeddableChat.closeChatVisibility();
  }

  async model(params) {
    const topic = this.store.createRecord("topic", { id: params.topic_id });

    // Populates the topic (chat_channel_id, slug, post stream) from the
    // server-preloaded payload when available, falling back to a request.
    await topic.postStream.refresh();

    return topic;
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    this.controllerFor("topic").set("model", model);
  }
}
