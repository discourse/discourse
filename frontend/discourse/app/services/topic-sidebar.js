import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import Topic from "discourse/models/topic";

export default class TopicSidebarService extends Service {
  @tracked selectedTopicId = null;

  selectTopic(topicId) {
    this.selectedTopicId = topicId;
    this.topic = Topic.create({ id: topicId });
    this.topic.postStream.refresh();
  }

  clearSelectedTopic() {
    this.selectedTopicId = null;
    this.topic = null;
  }
}
