import Controller, { inject as controller } from "@ember/controller";
import { gt, readOnly } from "@ember/object/computed";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { action } from "@ember/object";

export default Controller.extend({
  application: controller(),

  queryParams: ["order", "asc", "filter"],

  order: "",
  asc: true,
  filter: null,
  filterInput: null,

  loading: false,
  isOwner: readOnly("model.is_group_owner"),
  showActions: false,

  @observes("filterInput")
  _setFilter: discourseDebounce(function() {
    this.set("filter", this.filterInput);
  }, 500),

  @observes("order", "asc", "filter")
  _filtersChanged() {
    this.findMembers(true);
  },

  findMembers(refresh) {
    if (this.loading || !this.model) {
      return;
    }

    if (!refresh && this.model.members.length >= this.model.user_count) {
      this.set("application.showFooter", true);
      return;
    }

    this.set("loading", true);
    this.model.findMembers(this.memberParams, refresh).finally(() => {
      this.setProperties({
        "application.showFooter":
          this.model.members.length >= this.model.user_count,
        loading: false
      });
    });
  },

  @discourseComputed("order", "asc", "filter")
  memberParams(order, asc, filter) {
    return { order, asc, filter };
  },

  hasMembers: gt("model.members.length", 0),

  @discourseComputed("model")
  canManageGroup(model) {
    return this.currentUser && this.currentUser.canManageGroup(model);
  },

  @discourseComputed
  filterPlaceholder() {
    if (this.currentUser && this.currentUser.admin) {
      return "groups.members.filter_placeholder_admin";
    } else {
      return "groups.members.filter_placeholder";
    }
  },

  @action
  loadMore() {
    this.findMembers();
  },

  @action
  toggleActions() {
    this.toggleProperty("showActions");
  },

  @action
  actOnGroup(member, actionId) {
    switch (actionId) {
      case "removeMember":
        this.removeMember(member);
        break;
      case "makeOwner":
        this.makeOwner(member.username);
        break;
      case "removeOwner":
        this.removeOwner(member);
        break;
    }
  },

  @action
  removeMember(user) {
    this.model.removeMember(user, this.memberParams);
  },

  @action
  makeOwner(username) {
    this.model.addOwners(username);
  },

  @action
  removeOwner(user) {
    this.model.removeOwner(user);
  },

  @action
  addMembers() {
    if (this.usernames && this.usernames.length > 0) {
      this.model
        .addMembers(this.usernames)
        .then(() => this.set("usernames", []))
        .catch(popupAjaxError);
    }
  }
});
