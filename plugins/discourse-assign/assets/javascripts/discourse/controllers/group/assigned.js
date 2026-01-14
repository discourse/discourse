import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import discourseComputed from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import { trackedArray } from "discourse/lib/tracked-tools";

export default class GroupAssigned extends Controller {
  @service router;
  @controller application;

  @tracked filter = "";
  @tracked filterName = "";
  @tracked loading = false;
  @tracked offset = 0;
  @trackedArray members = [];

  @discourseComputed("router.currentRoute.queryParams.order")
  order(order) {
    return order || "";
  }

  @discourseComputed("router.currentRoute.queryParams.ascending")
  ascending(ascending) {
    return ascending || false;
  }

  @discourseComputed("router.currentRoute.queryParams.search")
  search(search) {
    return search || "";
  }

  @discourseComputed("site.mobileView")
  isDesktop(mobileView) {
    return !mobileView;
  }

  _setFilter(filter) {
    this.set("loading", true);
    this.set("offset", 0);
    this.set("filter", filter);

    const groupName = this.group.name;
    ajax(`/assign/members/${groupName}`, {
      type: "GET",
      data: { filter: this.filter, offset: this.offset },
    })
      .then((result) => {
        if (this.router.currentRoute.params.filter !== "everyone") {
          this.router.transitionTo(
            "group.assigned.show",
            groupName,
            "everyone"
          );
        }
        this.set("members", result.members);
      })
      .finally(() => {
        this.set("loading", false);
      });
  }

  async findMembers(refresh) {
    if (refresh) {
      this.members = this.model.members;
      return;
    }

    if (this.loading || !this.model) {
      return;
    }

    if (this.model.members.length >= this.offset + 50) {
      try {
        this.loading = true;
        this.offset = this.offset + 50;

        const result = await ajax(`/assign/members/${this.group.name}`, {
          type: "GET",
          data: { filter: this.filter, offset: this.offset },
        });

        this.members.push(...result.members);
      } finally {
        this.loading = false;
      }
    }
  }

  @action
  loadMore() {
    this.findMembers();
  }

  @action
  onChangeFilterName(value) {
    discourseDebounce(this, this._setFilter, value, INPUT_DELAY * 2);
  }
}
