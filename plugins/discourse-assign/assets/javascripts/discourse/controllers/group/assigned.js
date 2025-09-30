import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import discourseComputed from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";

export default class GroupAssigned extends Controller {
  @service router;
  @controller application;

  loading = false;
  offset = 0;
  filterName = "";
  filter = "";

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

  findMembers(refresh) {
    if (refresh) {
      this.set("members", this.model.members);
      return;
    }

    if (this.loading || !this.model) {
      return;
    }

    if (this.model.members.length >= this.offset + 50) {
      this.set("loading", true);
      this.set("offset", this.offset + 50);
      ajax(`/assign/members/${this.group.name}`, {
        type: "GET",
        data: { filter: this.filter, offset: this.offset },
      })
        .then((result) => {
          this.members.pushObjects(result.members);
        })
        .finally(() => this.set("loading", false));
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
