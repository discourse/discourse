import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import Topic from "discourse/models/topic";

export default class TopicSidebarService extends Service {
  @tracked selectedTopicId = null;
  @tracked topic = null;

  #closeHandler = null;

  selectTopic(topicId) {
    this.selectedTopicId = topicId;
    this.topic = Topic.create({ id: topicId });
    this.topic.postStream.refresh();
  }

  clearSelectedTopic() {
    this.selectedTopicId = null;
    this.topic = null;
    this.#closeHandler?.();
  }

  registerCloseHandler(handler) {
    this.#closeHandler = handler;
    return () => {
      if (this.#closeHandler === handler) {
        this.#closeHandler = null;
      }
    };
  }
}
