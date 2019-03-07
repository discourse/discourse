import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Group from "discourse/models/group";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import debounce from "discourse/lib/debounce";

export default Ember.Controller.extend({
  queryParams: ["order", "desc", "filter"],
  order: "",
  desc: null,
  loading: false,
  limit: null,
  offset: null,
  filter: null,
  filterInput: null,
  application: Ember.inject.controller(),

  @observes("filterInput")
  _setFilter: debounce(function() {
    this.set("filter", this.get("filterInput"));
  }, 500),

  @observes("order", "desc", "filter")
  refreshRequesters(force) {
    if (this.get("loading") || !this.get("model")) {
      return;
    }

    if (
      !force &&
      this.get("count") &&
      this.get("model.requesters.length") >= this.get("count")
    ) {
      this.set("application.showFooter", true);
      return;
    }

    this.set("loading", true);
    this.set("application.showFooter", false);

    Group.loadMembers(
      this.get("model.name"),
      force ? 0 : this.get("model.requesters.length"),
      this.get("limit"),
      {
        order: this.get("order"),
        desc: this.get("desc"),
        filter: this.get("filter"),
        requesters: true
      }
    ).then(result => {
      const requesters = (!force && this.get("model.requesters")) || [];
      requesters.addObjects(result.members.map(m => Discourse.User.create(m)));
      this.set("model.requesters", requesters);

      this.setProperties({
        loading: false,
        count: result.meta.total,
        limit: result.meta.limit,
        offset: Math.min(
          result.meta.offset + result.meta.limit,
          result.meta.total
        )
      });
    });
  },

  @computed("model.requesters")
  hasRequesters(requesters) {
    return requesters && requesters.length > 0;
  },

  @computed
  filterPlaceholder() {
    if (this.currentUser && this.currentUser.admin) {
      return "groups.members.filter_placeholder_admin";
    } else {
      return "groups.members.filter_placeholder";
    }
  },

  replyRequest(data) {
    ajax(`/groups/${this.get("model.id")}/membership_request.json`, {
      data,
      type: "PUT"
    }).catch(popupAjaxError);
  },

  actions: {
    loadMore() {
      this.refreshRequesters();
    },

    acceptRequest(user) {
      this.replyRequest({ user_id: user.get("id"), accept: true });
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
      this.replyRequest({ user_id: user.get("id") });
      user.setProperties({
        request_accepted: false,
        request_denied: true
      });
    }
  }
});
