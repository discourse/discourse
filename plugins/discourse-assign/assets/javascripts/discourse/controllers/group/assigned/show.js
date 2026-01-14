import { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import UserTopicsList from "discourse/controllers/user-topics-list";
import BulkSelectHelper from "discourse/lib/bulk-select-helper";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";

export default class GroupAssignedShow extends UserTopicsList {
  @service taskActions;
  @service router;
  @controller user;

  queryParams = ["order", "ascending", "search"];
  order = "";
  ascending = false;
  search = "";
  bulkSelectEnabled = false;
  bulkSelectHelper = new BulkSelectHelper(this);
  selected = [];

  @alias("currentUser.staff") canBulkSelect;

  _setSearchTerm(searchTerm) {
    this.set("search", searchTerm);
    this.refreshModel();
  }

  refreshModel() {
    this.set("loading", true);
    this.store
      .findFiltered("topicList", {
        filter: this.model.filter,
        params: {
          order: this.order,
          ascending: this.ascending,
          search: this.search,
          direct: this.model.params.direct,
        },
      })
      .then((result) => this.set("model", result))
      .finally(() => {
        this.set("loading", false);
      });
  }

  @action
  async unassign(targetId, targetType = "Topic") {
    await this.taskActions.unassign(targetId, targetType);
    this.router.refresh();
  }

  @action
  reassign(topic) {
    this.taskActions.showAssignModal(topic, {
      onSuccess: () => this.router.refresh(),
    });
  }

  @action
  changeSort(sortBy) {
    if (sortBy === this.order) {
      this.toggleProperty("ascending");
      this.refreshModel();
    } else {
      this.setProperties({ order: sortBy, ascending: false });
      this.refreshModel();
    }
  }

  @action
  onChangeFilter(value) {
    discourseDebounce(this, this._setSearchTerm, value, INPUT_DELAY * 2);
  }

  @action
  toggleBulkSelect() {
    this.toggleProperty("bulkSelectEnabled");
  }

  @action
  refresh() {
    this.refreshModel();
  }
}
