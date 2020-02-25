import Controller, { inject } from "@ember/controller";
import { alias } from "@ember/object/computed";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
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
  isOwner: alias("model.is_group_owner"),
  showActions: false,

  @observes("filterInput")
  _setFilter: discourseDebounce(function() {
    this.set("filter", this.filterInput);
  }, 500),

  @observes("order", "desc", "filter")
  _filtersChanged() {
    this.findMembers(true);
  },

  findMembers(refresh) {
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
    model.findMembers(this.memberParams, refresh).finally(() => {
      this.set(
        "application.showFooter",
        model.members.length >= model.user_count
      );
      this.set("loading", false);
    });
  },

  @discourseComputed("order", "desc", "filter")
  memberParams(order, desc, filter) {
    return { order, desc, filter };
  },

  @discourseComputed("model.members.[]")
  hasMembers(members) {
    return members && members.length > 0;
  },

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

  actions: {
    loadMore() {
      this.findMembers();
    },

    toggleActions() {
      this.toggleProperty("showActions");
    },

    actOnGroup(member, actionId) {
      switch (actionId) {
        case "removeMember":
          this.send("removeMember", member);
          break;
        case "makeOwner":
          this.send("makeOwner", member.username);
          break;
        case "removeOwner":
          this.send("removeOwner", member);
          break;
      }
    },

    removeMember(user) {
      this.model.removeMember(user, this.memberParams);
    },

    makeOwner(username) {
      this.model.addOwners(username);
    },

    removeOwner(user) {
      this.model.removeOwner(user);
    },

    addMembers() {
      const usernames = this.usernames;
      if (usernames && usernames.length > 0) {
        this.model
          .addMembers(usernames)
          .then(() => this.set("usernames", []))
          .catch(popupAjaxError);
      }
    }
  }
});
