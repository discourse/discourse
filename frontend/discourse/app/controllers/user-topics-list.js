import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { or } from "@ember/object/computed";
import { isNone } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import BulkSelectHelper from "discourse/lib/bulk-select-helper";
import { defineTrackedProperty } from "discourse/lib/tracked-tools";
import Topic from "discourse/models/topic";
import {
  NEW_FILTER,
  UNREAD_FILTER,
} from "discourse/routes/build-private-messages-route";
import { QUERY_PARAMS } from "discourse/routes/user-topic-list";

// Lists of topics on a user's page.
export default class UserTopicsListController extends Controller {
  @tracked model;

  hideCategory = false;
  showPosters = false;
  channel = null;
  tagsForUser = null;
  queryParams = Object.keys(QUERY_PARAMS);

  bulkSelectHelper = new BulkSelectHelper(this);

  @or("currentUser.canManageTopic", "showDismissRead", "showResetNew")
  canBulkSelect;

  constructor() {
    super(...arguments);

    for (const [name, info] of Object.entries(QUERY_PARAMS)) {
      defineTrackedProperty(this, name, info.default);
    }
  }

  @dependentKeyCompat
  get incomingCount() {
    return this.pmTopicTrackingState.newIncoming.length;
  }

  get bulkSelectEnabled() {
    return this.bulkSelectHelper.bulkSelectEnabled;
  }

  get selected() {
    return this.bulkSelectHelper.selected;
  }

  @computed("model.topics.length", "incomingCount")
  get noContent() {
    return this.model?.topics?.length === 0 && this.incomingCount === 0;
  }

  @computed("filter", "model.topics.length")
  get showResetNew() {
    return this.filter === NEW_FILTER && this.model?.topics?.length;
  }

  @computed("filter", "model.topics.length")
  get showDismissRead() {
    return this.filter === UNREAD_FILTER && this.model?.topics?.length;
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
    if (isNone(this.ascending)) {
      return this.model.get("params.ascending") === "true";
    } else {
      return this.ascending.toString() === "true";
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
  async showInserted(event) {
    event?.preventDefault();

    if (this.model.loadingBefore) {
      return;
    }

    try {
      const topicIds = [...this.pmTopicTrackingState.newIncoming];
      await this.model.loadBefore(topicIds);
      this.pmTopicTrackingState.resetIncomingTracking(topicIds);
    } catch (e) {
      popupAjaxError(e);
    }
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
