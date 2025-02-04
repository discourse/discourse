import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { observes } from "@ember-decorators/object";
import discourseComputed from "discourse/lib/decorators";

export default class GroupManageLogsController extends Controller {
  @controller group;
  @controller application;

  loading = false;
  offset = 0;
  filters = EmberObject.create();

  @discourseComputed(
    "filters.action",
    "filters.acting_user",
    "filters.target_user",
    "filters.subject"
  )
  filterParams(filtersAction, acting_user, target_user, subject) {
    return { action: filtersAction, acting_user, target_user, subject };
  }

  @observes(
    "filters.action",
    "filters.acting_user",
    "filters.target_user",
    "filters.subject"
  )
  _refreshModel() {
    this.get("group.model")
      .findLogs(0, this.filterParams)
      .then((results) => {
        this.set("offset", 0);

        this.model.setProperties({
          logs: results.logs,
          all_loaded: results.all_loaded,
        });
      });
  }

  reset() {
    this.setProperties({
      offset: 0,
      filters: EmberObject.create(),
    });
  }

  @action
  loadMore() {
    if (this.get("model.all_loaded")) {
      return;
    }

    this.set("loading", true);

    this.get("group.model")
      .findLogs(this.offset + 1, this.filterParams)
      .then((results) => {
        results.logs.forEach((result) =>
          this.get("model.logs").addObject(result)
        );
        this.incrementProperty("offset");
        this.set("model.all_loaded", results.all_loaded);
      })
      .finally(() => this.set("loading", false));
  }

  @action
  clearFilter(key) {
    this.set(`filters.${key}`, "");
  }
}
