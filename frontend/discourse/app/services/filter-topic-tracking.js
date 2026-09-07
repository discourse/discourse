import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { parseFilterNewQuery } from "discourse/lib/filter-new-query";

export default class FilterTopicTracking extends Service {
  @service topicTrackingState;

  @tracked matches;
  @tracked query;

  get newRepliesCount() {
    this.topicTrackingState.get("messageCount");
    return this.matches
      ? this.topicTrackingState.countUnread({
          customFilterFn: (topic) => this.matches.has(topic.topic_id),
        })
      : undefined;
  }

  get newTopicsCount() {
    this.topicTrackingState.get("messageCount");
    return this.matches
      ? this.topicTrackingState.countNew({
          customFilterFn: (topic) => this.matches.has(topic.topic_id),
        })
      : undefined;
  }

  update(query, topicIds) {
    this.query = parseFilterNewQuery(query).baseQuery;
    this.matches = topicIds ? new Set(topicIds) : undefined;
  }

  stop() {
    this.query = undefined;
    this.matches = undefined;
  }
}
