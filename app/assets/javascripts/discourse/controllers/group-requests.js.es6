import { inject } from '@ember/controller';
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Group from "discourse/models/group";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import debounce from "discourse/lib/debounce";

export default Controller.extend({
  queryParams: ["order", "desc", "filter"],
  order: "",
  desc: null,
  loading: false,
  limit: null,
  offset: null,
  filter: null,
  filterInput: null,
  application: inject(),

  @observes("filterInput")
  _setFilter: debounce(function() {
    this.set("filter", this.filterInput);
  }, 500),

  @observes("order", "desc", "filter")
  refreshRequesters(force) {
    if (this.loading || !this.model) {
      return;
    }

    if (
      !force &&
      this.count &&
      this.get("model.requesters.length") >= this.count
    ) {
      this.set("application.showFooter", true);
      return;
    }

    this.set("loading", true);
    this.set("application.showFooter", false);

    Group.loadMembers(
      this.get("model.name"),
      force ? 0 : this.get("model.requesters.length"),
      this.limit,
      {
        order: this.order,
        desc: this.desc,
        filter: this.filter,
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

  handleRequest(data) {
    ajax(`/groups/${this.get("model.id")}/handle_membership_request.json`, {
      data,
      type: "PUT"
    }).catch(popupAjaxError);
  },

  actions: {
    loadMore() {
      this.refreshRequesters();
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
