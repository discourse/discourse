import Controller, { inject } from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";

export default Controller.extend({
  application: inject(),

  queryParams: ["order", "desc", "filter"],

  order: "",
  desc: null,
  filter: null,
  filterInput: null,

  loading: false,

  @observes("filterInput")
  _setFilter: discourseDebounce(function() {
    this.set("filter", this.filterInput);
  }, 500),

  @observes("order", "desc", "filter")
  _filtersChanged() {
    this.findRequesters(true);
  },

  findRequesters(refresh) {
    if (this.loading) {
      return;
    }

    const model = this.model;
    if (!model) {
      return;
    }

    if (!refresh && model.members.length >= model.user_count) {
      this.set("application.showFooter", true);
      return;
    }

    this.set("loading", true);
    model.findRequesters(this.memberParams, refresh).finally(() => {
      this.set(
        "application.showFooter",
        model.requesters.length >= model.user_count
      );
      this.set("loading", false);
    });
  },

  @discourseComputed("order", "desc", "filter")
  memberParams(order, desc, filter) {
    return { order, desc, filter };
  },

  @discourseComputed("model.requesters.[]")
  hasRequesters(requesters) {
    return requesters && requesters.length > 0;
  },

  @discourseComputed
  filterPlaceholder() {
    if (this.currentUser && this.currentUser.admin) {
      return "groups.members.filter_placeholder_admin";
    } else {
      return "groups.members.filter_placeholder";
    }
  },

  handleRequest(data) {
    ajax(`/groups/${this.get("model.id")}/handle_membership_request.json`, {
      data,
      type: "PUT"
    }).catch(popupAjaxError);
  },

  actions: {
    loadMore() {
      this.findRequesters();
    },

    acceptRequest(user) {
      this.handleRequest({ user_id: user.get("id"), accept: true });
      user.setProperties({
        request_accepted: true,
        request_denied: false
      });
    },

    undoAcceptRequest(user) {
      ajax("/groups/" + this.get("model.id") + "/members.json", {
        type: "DELETE",
        data: { user_id: user.get("id") }
      }).then(() => {
        user.set("request_undone", true);
      });
    },

    denyRequest(user) {
      this.handleRequest({ user_id: user.get("id") });
      user.setProperties({
        request_accepted: false,
        request_denied: true
      });
    }
  }
});
