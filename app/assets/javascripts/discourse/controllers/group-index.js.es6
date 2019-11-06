import { alias } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
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
  isOwner: alias("model.is_group_owner"),
  showActions: false,
  filter: null,
  filterInput: null,
  application: inject(),

  @observes("filterInput")
  _setFilter: debounce(function() {
    this.set("filter", this.filterInput);
  }, 500),

  @observes("order", "desc", "filter")
  refreshMembers() {
    this.set("loading", true);
    const model = this.model;

    if (model && model.can_see_members) {
      model.findMembers(this.memberParams).finally(() => {
        this.set(
          "application.showFooter",
          model.members.length >= model.user_count
        );
        this.set("loading", false);
      });
    }
  },

  @computed("order", "desc", "filter")
  memberParams(order, desc, filter) {
    return { order, desc, filter };
  },

  @computed("model.members")
  hasMembers(members) {
    return members && members.length > 0;
  },

  @computed("model")
  canManageGroup(model) {
    return this.currentUser && this.currentUser.canManageGroup(model);
  },

  @computed
  filterPlaceholder() {
    if (this.currentUser && this.currentUser.admin) {
      return "groups.members.filter_placeholder_admin";
    } else {
      return "groups.members.filter_placeholder";
    }
  },

  actions: {
    toggleActions() {
      this.toggleProperty("showActions");
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
    },

    loadMore() {
      if (this.loading) {
        return;
      }
      if (this.get("model.members.length") >= this.get("model.user_count")) {
        this.set("application.showFooter", true);
        return;
      }

      this.set("loading", true);

      Group.loadMembers(
        this.get("model.name"),
        this.get("model.members.length"),
        this.limit,
        { order: this.order, desc: this.desc }
      ).then(result => {
        this.get("model.members").addObjects(
          result.members.map(member => Discourse.User.create(member))
        );
        this.setProperties({
          loading: false,
          user_count: result.meta.total,
          limit: result.meta.limit,
          offset: Math.min(
            result.meta.offset + result.meta.limit,
            result.meta.total
          )
        });
      });
    }
  }
});
