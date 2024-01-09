import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { or, reads } from "@ember/object/computed";
import BulkSelectHelper from "discourse/lib/bulk-select-helper";
import { defineTrackedProperty } from "discourse/lib/tracked-tools";
import Topic from "discourse/models/topic";
import {
  NEW_FILTER,
  UNREAD_FILTER,
} from "discourse/routes/build-private-messages-route";
import discourseComputed from "discourse-common/utils/decorators";

export const queryParams = {
  ascending: { replace: true, refreshModel: true, default: false },
  order: { replace: true, refreshModel: true },
};

// Lists of topics on a user's page.
export default class UserTopicsListController extends Controller {
  @tracked model;

  hideCategory = false;
  showPosters = false;
  channel = null;
  tagsForUser = null;
  queryParams = Object.keys(queryParams);

  bulkSelectHelper = new BulkSelectHelper(this);

  @reads("pmTopicTrackingState.newIncoming.length") incomingCount;

  @or("currentUser.canManageTopic", "showDismissRead", "showResetNew")
  canBulkSelect;

  constructor() {
    super(...arguments);
    for (const [name, info] of Object.entries(queryParams)) {
      defineTrackedProperty(this, name, info.default);
    }
  }

  get bulkSelectEnabled() {
    return this.bulkSelectHelper.bulkSelectEnabled;
  }

  get selected() {
    return this.bulkSelectHelper.selected;
  }

  @discourseComputed("model.topics.length", "incomingCount")
  noContent(topicsLength, incomingCount) {
    return topicsLength === 0 && incomingCount === 0;
  }

  @discourseComputed("filter", "model.topics.length")
  showResetNew(filter, hasTopics) {
    return filter === NEW_FILTER && hasTopics;
  }

  @discourseComputed("filter", "model.topics.length")
  showDismissRead(filter, hasTopics) {
    return filter === UNREAD_FILTER && hasTopics;
  }

  subscribe() {
    this.pmTopicTrackingState.trackIncoming(this.inbox, this.filter);
  }

  unsubscribe() {
    this.pmTopicTrackingState.stopIncomingTracking();
  }

  @action
  changeSort(sortBy) {
    if (sortBy === this.resolvedOrder) {
      this.ascending = !this.resolvedAscending;
    } else {
      this.ascending = false;
    }
    this.order = sortBy;
  }

  get resolvedAscending() {
    if (this.ascending === undefined || this.ascending === null) {
      return this.model.get("params.ascending") === "true";
    } else {
      return [true, "true"].includes(this.ascending);
    }
  }

  get resolvedOrder() {
    return this.order ?? this.model.get("params.order") ?? "activity";
  }

  @action
  resetNew() {
    const topicIds = this.selected
      ? this.selected.map((topic) => topic.id)
      : null;

    const opts = {
      inbox: this.inbox,
      topicIds,
    };

    if (this.group) {
      opts.groupName = this.group.name;
    }

    Topic.pmResetNew(opts).then((result) => {
      if (result && result.topic_ids.length > 0) {
        this.pmTopicTrackingState.removeTopics(result.topic_ids);
        this.send("refresh");
      }
    });
  }

  @action
  loadMore() {
    this.model.loadMore();
  }

  @action
  showInserted(event) {
    event?.preventDefault();
    this.model.loadBefore(this.pmTopicTrackingState.newIncoming);
    this.pmTopicTrackingState.resetIncomingTracking();
  }

  @action
  refresh() {
    this.send("triggerRefresh");
  }

  @action
  toggleBulkSelect() {
    this.bulkSelectHelper.toggleBulkSelect();
  }

  @action
  dismissRead(operationType, options) {
    this.bulkSelectHelper.dismissRead(operationType, options);
  }

  @action
  updateAutoAddTopicsToBulkSelect(value) {
    this.bulkSelectHelper.autoAddTopicsToBulkSelect = value;
  }

  @action
  addTopicsToBulkSelect(topics) {
    this.bulkSelectHelper.addTopics(topics);
  }
}
