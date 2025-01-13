import EmberObject from "@ember/object";
import TopicStatus from "discourse/components/topic-status";
import deprecated from "discourse/lib/deprecated";
import { RAW_TOPIC_LIST_DEPRECATION_OPTIONS } from "discourse/lib/plugin-api";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";

export default class RawTopicStatus extends EmberObject {
  static reopen() {
    deprecated(
      "Modifying raw-view:topic-status with `reopen` is deprecated. Use the value transformer `topic-list-columns` and other new topic-list plugin APIs instead.",
      RAW_TOPIC_LIST_DEPRECATION_OPTIONS
    );

    return super.reopen(...arguments);
  }

  static reopenClass() {
    deprecated(
      "Modifying raw-view:topic-status with `reopenClass` is deprecated. Use the value transformer `topic-list-columns` and other new topic-list plugin APIs instead.",
      RAW_TOPIC_LIST_DEPRECATION_OPTIONS
    );

    return super.reopenClass(...arguments);
  }

  get html() {
    return rawRenderGlimmer(this, "", TopicStatus, {
      topic: this.topic,
      showPrivateMessageIcon: this.showPrivateMessageIcon,
    });
  }
}
