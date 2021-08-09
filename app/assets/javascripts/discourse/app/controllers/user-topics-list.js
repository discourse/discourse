import Controller, { inject as controller } from "@ember/controller";
import discourseComputed, {
  observes,
  on,
} from "discourse-common/utils/decorators";
import BulkTopicSelection from "discourse/mixins/bulk-topic-selection";
import { action } from "@ember/object";
import Topic from "discourse/models/topic";

import {
  NEW_FILTER,
  UNREAD_FILTER,
} from "discourse/routes/build-private-messages-route";

// Lists of topics on a user's page.
export default Controller.extend(BulkTopicSelection, {
  application: controller(),

  hideCategory: false,
  showPosters: false,
  incomingCount: 0,
  channel: null,
  tagsForUser: null,

  @on("init")
  _initialize() {
    this.newIncoming = [];
  },

  saveScrollPosition() {
    this.session.set("topicListScrollPosition", $(window).scrollTop());
  },

  @observes("model.canLoadMore")
  _showFooter() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  },

  @discourseComputed("incomingCount")
  hasIncoming(incomingCount) {
    return incomingCount > 0;
  },

  @discourseComputed("filter", "model.topics.length")
  showResetNew(filter, hasTopics) {
    return filter === NEW_FILTER && hasTopics;
  },

  @discourseComputed("filter", "model.topics.length")
  showDismissRead(filter, hasTopics) {
    return filter === UNREAD_FILTER && hasTopics;
  },

  subscribe(channel) {
    this.set("channel", channel);

    this.messageBus.subscribe(channel, (data) => {
      if (this.newIncoming.indexOf(data.topic_id) === -1) {
        this.newIncoming.push(data.topic_id);
        this.incrementProperty("incomingCount");
      }
    });
  },

  unsubscribe() {
    const channel = this.channel;
    if (channel) {
      this.messageBus.unsubscribe(channel);
    }
    this._resetTracking();
    this.set("channel", null);
  },

  _resetTracking() {
    this.setProperties({
      newIncoming: [],
      incomingCount: 0,
    });
  },

  @action
  resetNew() {
    const topicIds = this.selected
      ? this.selected.map((topic) => topic.id)
      : null;

    const opts = {
      inbox: this.inbox,
      topicIds: topicIds,
    };

    if (this.group) {
      opts.groupName = this.group.name;
    }

    Topic.pmResetNew(opts).then(() => {
      this.send("refresh");
    });
  },

  @action
  loadMore() {
    this.model.loadMore();
  },

  @action
  showInserted() {
    this.model.loadBefore(this.newIncoming);
    this._resetTracking();
    return false;
  },
});
