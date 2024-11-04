import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { observes } from "@ember-decorators/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed, { debounce } from "discourse-common/utils/decorators";

export default class GroupRequestsController extends Controller {
  @controller application;

  queryParams = ["order", "asc", "filter"];
  order = "";
  asc = null;
  filter = null;
  filterInput = null;
  loading = false;

  get canLoadMore() {
    return (
      this.get("model.requesters")?.length < this.get("model.request_count")
    );
  }

  @observes("filterInput")
  filterInputChanged() {
    this._setFilter();
  }

  @debounce(500)
  _setFilter() {
    this.set("filter", this.filterInput);
  }

  @observes("order", "asc", "filter")
  _filtersChanged() {
    this.findRequesters(true);
  }

  findRequesters(refresh) {
    if (this.loading) {
      return;
    }

    const model = this.model;
    if (!model) {
      return;
    }

    if (!refresh && !this.canLoadMore) {
      return;
    }

    this.set("loading", true);
    model.findRequesters(this.memberParams, refresh).finally(() => {
      this.set("loading", false);
    });
  }

  @discourseComputed("order", "asc", "filter")
  memberParams(order, asc, filter) {
    return { order, asc, filter };
  }

  @discourseComputed("model.requesters.[]")
  hasRequesters(requesters) {
    return requesters && requesters.length > 0;
  }

  @discourseComputed
  filterPlaceholder() {
    if (this.currentUser && this.currentUser.admin) {
      return "groups.members.filter_placeholder_admin";
    } else {
      return "groups.members.filter_placeholder";
    }
  }

  handleRequest(data) {
    ajax(`/groups/${this.get("model.id")}/handle_membership_request.json`, {
      data,
      type: "PUT",
    }).catch(popupAjaxError);
  }

  @action
  loadMore() {
    this.findRequesters();
  }

  @action
  acceptRequest(user) {
    this.handleRequest({ user_id: user.get("id"), accept: true });
    user.setProperties({
      request_accepted: true,
      request_denied: false,
    });
  }

  @action
  undoAcceptRequest(user) {
    ajax("/groups/" + this.get("model.id") + "/members.json", {
      type: "DELETE",
      data: { user_id: user.get("id") },
    }).then(() => {
      user.set("request_undone", true);
    });
  }

  @action
  denyRequest(user) {
    this.handleRequest({ user_id: user.get("id") });
    user.setProperties({
      request_accepted: false,
      request_denied: true,
    });
  }

  @action
  updateOrder(field, asc) {
    this.setProperties({
      order: field,
      asc,
    });
  }
}
