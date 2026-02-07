import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Composer from "discourse/models/composer";

export default class StyleguideShow extends Controller {
  @service composer;

  @action
  dummyAction() {}

  @action
  createTopic() {
    this.composer.openNewTopic();
  }

  @action
  replyToPost() {
    const topic = this.dummy?.topic;
    if (topic) {
      this.composer.open({
        action: Composer.REPLY,
        draftKey: topic.draft_key || `topic_${topic.id}`,
        topic,
      });
    }
  }
}
