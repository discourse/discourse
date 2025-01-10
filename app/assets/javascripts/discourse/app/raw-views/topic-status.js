import EmberObject from "@ember/object";
import TopicStatus from "discourse/components/topic-status";
import { RAW_TOPIC_LIST_DEPRECATION_OPTIONS } from "discourse/lib/plugin-api";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
import deprecated from "discourse-common/lib/deprecated";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

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

  @discourseComputed
  renderDiv() {
    return this.statuses.length > 0;
  }

  @discourseComputed
  statuses() {
    const topic = this.topic;
    const results = [];

    // TODO: implement in gjs variant?
    if (topic.bookmarked) {
      const postNumbers = topic.bookmarked_post_numbers;
      let url = topic.url;
      let extraClasses = "";
      if (postNumbers && postNumbers[0] > 1) {
        url += `/${postNumbers[0]}`;
      } else {
        extraClasses = "op-bookmark";
      }

      results.push({
        extraClasses,
        icon: "bookmark",
        key: "bookmarked",
        href: url,
      });
    }

    results.forEach((result) => {
      result.title = i18n(`topic_statuses.${result.key}.help`);
    });

    return results;
  }

  get html() {
    return rawRenderGlimmer(this, "", TopicStatus, {
      topic: this.topic,
      showPrivateMessageIcon: this.showPrivateMessageIcon,
    });
  }
}
