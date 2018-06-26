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
  isOwner: Ember.computed.alias("model.is_group_owner"),
  showActions: false,
  filter: null,
  filterInput: null,
  application: Ember.inject.controller(),

  @observes("filterInput")
  _setFilter: debounce(function() {
    this.set("filter", this.get("filterInput"));
  }, 500),

  @observes("order", "desc", "filter")
  refreshMembers() {
    this.set("loading", true);
    const model = this.get("model");

    if (model) {
      model.findMembers(this.get("memberParams")).finally(() => {
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
      this.get("model").removeMember(user, this.get("memberParams"));
    },

    makeOwner(username) {
      this.get("model").addOwners(username);
    },

    removeOwner(user) {
      this.get("model").removeOwner(user);
    },

    addMembers() {
      const usernames = this.get("usernames");
      if (usernames && usernames.length > 0) {
        this.get("model")
          .addMembers(usernames)
          .then(() => this.set("usernames", []))
          .catch(popupAjaxError);
      }
    },

    loadMore() {
      if (this.get("loading")) {
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
        this.get("limit"),
        { order: this.get("order"), desc: this.get("desc") }
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
