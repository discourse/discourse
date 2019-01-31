import { ajax } from "discourse/lib/ajax";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import GroupHistory from "discourse/models/group-history";
import RestModel from "discourse/models/rest";
import Category from "discourse/models/category";
import User from "discourse/models/user";
import Topic from "discourse/models/topic";
import { popupAjaxError } from "discourse/lib/ajax-error";

const Group = RestModel.extend({
  limit: 50,
  offset: 0,
  user_count: 0,
  owners: [],

  hasOwners: Ember.computed.notEmpty("owners"),

  @computed("automatic_membership_email_domains")
  emailDomains(value) {
    return Ember.isEmpty(value) ? "" : value;
  },

  @computed("automatic")
  type(automatic) {
    return automatic ? "automatic" : "custom";
  },

  @computed("user_count")
  userCountDisplay(userCount) {
    // don't display zero its ugly
    if (userCount > 0) {
      return userCount;
    }
  },

  findMembers(params) {
    if (Ember.isEmpty(this.get("name"))) {
      return;
    }

    const offset = Math.min(
      this.get("user_count"),
      Math.max(this.get("offset"), 0)
    );

    return Group.loadMembers(
      this.get("name"),
      offset,
      this.get("limit"),
      params
    ).then(result => {
      var ownerIds = {};
      result.owners.forEach(owner => (ownerIds[owner.id] = true));

      this.setProperties({
        user_count: result.meta.total,
        limit: result.meta.limit,
        offset: result.meta.offset,
        members: result.members.map(member => {
          if (ownerIds[member.id]) {
            member.owner = true;
          }
          return User.create(member);
        }),
        owners: result.owners.map(owner => User.create(owner))
      });
    });
  },

  removeOwner(member) {
    var self = this;
    return ajax("/admin/groups/" + this.get("id") + "/owners.json", {
      type: "DELETE",
      data: { user_id: member.get("id") }
    }).then(function() {
      // reload member list
      self.findMembers();
    });
  },

  removeMember(member, params) {
    return ajax("/groups/" + this.get("id") + "/members.json", {
      type: "DELETE",
      data: { user_id: member.get("id") }
    }).then(() => {
      this.findMembers(params);
    });
  },

  addMembers(usernames, filter) {
    return ajax("/groups/" + this.get("id") + "/members.json", {
      type: "PUT",
      data: { usernames: usernames }
    }).then(response => {
      if (filter) {
        this._filterMembers(response);
      } else {
        this.findMembers();
      }
    });
  },

  addOwners(usernames, filter) {
    return ajax(`/admin/groups/${this.get("id")}/owners.json`, {
      type: "PUT",
      data: { group: { usernames: usernames } }
    }).then(response => {
      if (filter) {
        this._filterMembers(response);
      } else {
        this.findMembers();
      }
    });
  },

  _filterMembers(response) {
    return this.findMembers({ filter: response.usernames.join(",") });
  },

  @computed("display_name", "name")
  displayName(groupDisplayName, name) {
    return groupDisplayName || name;
  },

  @computed("flair_bg_color")
  flairBackgroundHexColor() {
    return this.get("flair_bg_color")
      ? this.get("flair_bg_color").replace(new RegExp("[^0-9a-fA-F]", "g"), "")
      : null;
  },

  @computed("flair_color")
  flairHexColor() {
    return this.get("flair_color")
      ? this.get("flair_color").replace(new RegExp("[^0-9a-fA-F]", "g"), "")
      : null;
  },

  @computed("mentionable_level")
  canEveryoneMention(mentionableLevel) {
    return mentionableLevel === "99";
  },

  @computed("visibility_level")
  isPrivate(visibilityLevel) {
    return visibilityLevel !== 0;
  },

  @observes("visibility_level", "canEveryoneMention")
  _updateAllowMembershipRequests() {
    if (this.get("isPrivate") || !this.get("canEveryoneMention")) {
      this.set("allow_membership_requests", false);
    }
  },

  @observes("visibility_level")
  _updatePublic() {
    if (this.get("isPrivate")) {
      this.set("public", false);
      this.set("allow_membership_requests", false);
    }
  },

  asJSON() {
    const attrs = {
      name: this.get("name"),
      mentionable_level: this.get("mentionable_level"),
      messageable_level: this.get("messageable_level"),
      visibility_level: this.get("visibility_level"),
      automatic_membership_email_domains: this.get("emailDomains"),
      automatic_membership_retroactive: !!this.get(
        "automatic_membership_retroactive"
      ),
      title: this.get("title"),
      primary_group: !!this.get("primary_group"),
      grant_trust_level: this.get("grant_trust_level"),
      incoming_email: this.get("incoming_email"),
      flair_url: this.get("flair_url"),
      flair_bg_color: this.get("flairBackgroundHexColor"),
      flair_color: this.get("flairHexColor"),
      bio_raw: this.get("bio_raw"),
      public_admission: this.get("public_admission"),
      public_exit: this.get("public_exit"),
      allow_membership_requests: this.get("allow_membership_requests"),
      full_name: this.get("full_name"),
      default_notification_level: this.get("default_notification_level"),
      membership_request_template: this.get("membership_request_template")
    };

    if (!this.get("id")) {
      attrs["usernames"] = this.get("usernames");
      attrs["owner_usernames"] = this.get("ownerUsernames");
    }

    return attrs;
  },

  create() {
    return ajax("/admin/groups", {
      type: "POST",
      data: { group: this.asJSON() }
    }).then(resp => {
      this.setProperties({
        id: resp.basic_group.id,
        usernames: null,
        ownerUsernames: null
      });

      this.findMembers();
    });
  },

  save() {
    return ajax(`/groups/${this.get("id")}`, {
      type: "PUT",
      data: { group: this.asJSON() }
    });
  },

  destroy() {
    if (!this.get("id")) {
      return;
    }
    return ajax("/admin/groups/" + this.get("id"), { type: "DELETE" });
  },

  findLogs(offset, filters) {
    return ajax(`/groups/${this.get("name")}/logs.json`, {
      data: { offset, filters }
    }).then(results => {
      return Ember.Object.create({
        logs: results["logs"].map(log => GroupHistory.create(log)),
        all_loaded: results["all_loaded"]
      });
    });
  },

  findPosts(opts) {
    opts = opts || {};

    const type = opts.type || "posts";

    var data = {};
    if (opts.beforePostId) {
      data.before_post_id = opts.beforePostId;
    }
    if (opts.categoryId) {
      data.category_id = parseInt(opts.categoryId);
    }

    return ajax(`/groups/${this.get("name")}/${type}.json`, { data }).then(
      posts => {
        return posts.map(p => {
          p.user = User.create(p.user);
          p.topic = Topic.create(p.topic);
          p.category = Category.findById(p.category_id);
          return Ember.Object.create(p);
        });
      }
    );
  },

  setNotification(notification_level, userId) {
    this.set("group_user.notification_level", notification_level);
    return ajax(`/groups/${this.get("name")}/notifications`, {
      data: { notification_level, user_id: userId },
      type: "POST"
    });
  },

  requestMembership(reason) {
    return ajax(`/groups/${this.get("name")}/request_membership`, {
      type: "POST",
      data: { reason: reason }
    });
  }
});

Group.reopenClass({
  findAll(opts) {
    return ajax("/groups/search.json", { data: opts }).then(groups => {
      return groups.map(g => Group.create(g));
    });
  },

  loadMembers(name, offset, limit, params) {
    return ajax("/groups/" + name + "/members.json", {
      data: _.extend(
        {
          limit: limit || 50,
          offset: offset || 0
        },
        params || {}
      )
    });
  },

  mentionable(name) {
    return ajax(`/groups/${name}/mentionable`);
  },

  messageable(name) {
    return ajax(`/groups/${name}/messageable`);
  },

  checkName(name) {
    return ajax("/groups/check-name", {
      data: { group_name: name }
    }).catch(popupAjaxError);
  }
});

export default Group;
