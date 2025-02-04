import EmberObject from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { equal } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";
import { observes } from "@ember-decorators/object";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import Category from "discourse/models/category";
import GroupHistory from "discourse/models/group-history";
import RestModel from "discourse/models/rest";
import Site from "discourse/models/site";
import Topic from "discourse/models/topic";
import User from "discourse/models/user";

export default class Group extends RestModel {
  static findAll(opts) {
    return ajax("/groups/search.json", { data: opts }).then((groups) =>
      groups.map((g) => Group.create(g))
    );
  }

  static loadMembers(name, opts) {
    return ajax(`/groups/${name}/members.json`, { data: opts });
  }

  static mentionable(name) {
    return ajax(`/groups/${name}/mentionable`);
  }

  static messageable(name) {
    return ajax(`/groups/${name}/messageable`);
  }

  static checkName(name) {
    return ajax("/groups/check-name", { data: { group_name: name } });
  }

  user_count = 0;
  limit = null;
  offset = null;
  request_count = 0;
  requestersLimit = null;
  requestersOffset = null;

  @equal("mentionable_level", 99) canEveryoneMention;
  init() {
    super.init(...arguments);
    this.setProperties({ members: [], requesters: [] });
  }

  @discourseComputed("automatic_membership_email_domains")
  emailDomains(value) {
    return isEmpty(value) ? "" : value;
  }

  @discourseComputed("associated_group_ids")
  associatedGroupIds(value) {
    return isEmpty(value) ? [] : value;
  }

  @discourseComputed("automatic")
  type(automatic) {
    return automatic ? "automatic" : "custom";
  }

  async reloadMembers(params, refresh) {
    if (isEmpty(this.name) || !this.can_see_members) {
      return;
    }

    if (refresh) {
      this.setProperties({ limit: null, offset: null });
    }

    params = Object.assign(
      { offset: (this.offset || 0) + (this.limit || 0) },
      params
    );

    const response = await Group.loadMembers(this.name, params);
    const ownerIds = new Set();
    response.owners.forEach((owner) => ownerIds.add(owner.id));

    const members = refresh ? [] : this.members;
    members.pushObjects(
      response.members.map((member) => {
        member.owner = ownerIds.has(member.id);
        member.primary = member.primary_group_name === this.name;
        return User.create(member);
      })
    );

    this.setProperties({
      members,
      user_count: response.meta.total,
      limit: response.meta.limit,
      offset: response.meta.offset,
    });
  }

  findRequesters(params, refresh) {
    if (isEmpty(this.name) || !this.can_see_members) {
      return Promise.reject();
    }

    if (refresh) {
      this.setProperties({ requestersOffset: null, requestersLimit: null });
    }

    params = Object.assign(
      {
        offset: (this.requestersOffset || 0) + (this.requestersLimit || 0),
        requesters: true,
      },
      params
    );

    return Group.loadMembers(this.name, params).then((result) => {
      const requesters = refresh ? [] : this.requesters;
      requesters.pushObjects(result.members.map((m) => User.create(m)));

      this.setProperties({
        requesters,
        request_count: result.meta.total,
        requestersLimit: result.meta.limit,
        requestersOffset: result.meta.offset,
      });
    });
  }

  async removeOwner(member) {
    await ajax(`/admin/groups/${this.id}/owners.json`, {
      type: "DELETE",
      data: { user_id: member.id },
    });
    await this.reloadMembers({}, true);
  }

  async removeMember(member, params) {
    await ajax(`/groups/${this.id}/members.json`, {
      type: "DELETE",
      data: { user_id: member.id },
    });
    await this.reloadMembers(params, true);
  }

  async leave() {
    await ajax(`/groups/${this.id}/leave.json`, {
      type: "DELETE",
    });
    this.set("can_see_members", this.members_visibility_level < 2);
    await this.reloadMembers({}, true);
  }

  async addMembers(usernames, filter, notifyUsers, emails = []) {
    const response = await ajax(`/groups/${this.id}/members.json`, {
      type: "PUT",
      data: { usernames, emails, notify_users: notifyUsers },
    });
    if (filter) {
      await this._filterMembers(response.usernames);
    } else {
      await this.reloadMembers();
    }
  }

  async join() {
    await ajax(`/groups/${this.id}/join.json`, {
      type: "PUT",
    });
    await this.reloadMembers({}, true);
  }

  async addOwners(usernames, filter, notifyUsers) {
    const response = await ajax(`/groups/${this.id}/owners.json`, {
      type: "PUT",
      data: { usernames, notify_users: notifyUsers },
    });

    if (filter) {
      await this._filterMembers(response.usernames);
    } else {
      await this.reloadMembers({}, true);
    }
  }

  _filterMembers(usernames) {
    return this.reloadMembers({ filter: usernames.join(",") });
  }

  @discourseComputed("display_name", "name")
  displayName(groupDisplayName, name) {
    return groupDisplayName || name;
  }

  @discourseComputed("flair_bg_color")
  flairBackgroundHexColor(flairBgColor) {
    return flairBgColor
      ? flairBgColor.replace(new RegExp("[^0-9a-fA-F]", "g"), "")
      : null;
  }

  @discourseComputed("flair_color")
  flairHexColor(flairColor) {
    return flairColor
      ? flairColor.replace(new RegExp("[^0-9a-fA-F]", "g"), "")
      : null;
  }

  @discourseComputed("visibility_level")
  isPrivate(visibilityLevel) {
    return visibilityLevel > 1;
  }

  @observes("isPrivate", "canEveryoneMention")
  _updateAllowMembershipRequests() {
    if (this.isPrivate || !this.canEveryoneMention) {
      this.set("allow_membership_requests", false);
    }
  }

  @dependentKeyCompat
  get watchingCategories() {
    if (
      this.site.lazy_load_categories &&
      this.watching_category_ids &&
      !Category.hasAsyncFoundAll(this.watching_category_ids)
    ) {
      Category.asyncFindByIds(this.watching_category_ids).then(() =>
        this.notifyPropertyChange("watching_category_ids")
      );
    }

    return Category.findByIds(this.get("watching_category_ids"));
  }

  set watchingCategories(categories) {
    this.set(
      "watching_category_ids",
      categories.map((c) => c.id)
    );
  }

  @dependentKeyCompat
  get trackingCategories() {
    if (
      this.site.lazy_load_categories &&
      this.tracking_category_ids &&
      !Category.hasAsyncFoundAll(this.tracking_category_ids)
    ) {
      Category.asyncFindByIds(this.tracking_category_ids).then(() =>
        this.notifyPropertyChange("tracking_category_ids")
      );
    }

    return Category.findByIds(this.get("tracking_category_ids"));
  }

  set trackingCategories(categories) {
    this.set(
      "tracking_category_ids",
      categories.map((c) => c.id)
    );
  }

  @dependentKeyCompat
  get watchingFirstPostCategories() {
    if (
      this.site.lazy_load_categories &&
      this.watching_first_post_category_ids &&
      !Category.hasAsyncFoundAll(this.watching_first_post_category_ids)
    ) {
      Category.asyncFindByIds(this.watching_first_post_category_ids).then(() =>
        this.notifyPropertyChange("watching_first_post_category_ids")
      );
    }

    return Category.findByIds(this.get("watching_first_post_category_ids"));
  }

  set watchingFirstPostCategories(categories) {
    this.set(
      "watching_first_post_category_ids",
      categories.map((c) => c.id)
    );
  }

  @dependentKeyCompat
  get regularCategories() {
    if (
      this.site.lazy_load_categories &&
      this.regular_category_ids &&
      !Category.hasAsyncFoundAll(this.regular_category_ids)
    ) {
      Category.asyncFindByIds(this.regular_category_ids).then(() =>
        this.notifyPropertyChange("regular_category_ids")
      );
    }

    return Category.findByIds(this.get("regular_category_ids"));
  }

  set regularCategories(categories) {
    this.set(
      "regular_category_ids",
      categories.map((c) => c.id)
    );
  }

  @dependentKeyCompat
  get mutedCategories() {
    if (
      this.site.lazy_load_categories &&
      this.muted_category_ids &&
      !Category.hasAsyncFoundAll(this.muted_category_ids)
    ) {
      Category.asyncFindByIds(this.muted_category_ids).then(() =>
        this.notifyPropertyChange("muted_category_ids")
      );
    }

    return Category.findByIds(this.get("muted_category_ids"));
  }

  set mutedCategories(categories) {
    this.set(
      "muted_category_ids",
      categories.map((c) => c.id)
    );
  }

  asJSON() {
    const attrs = {
      name: this.name,
      mentionable_level: this.mentionable_level,
      messageable_level: this.messageable_level,
      visibility_level: this.visibility_level,
      members_visibility_level: this.members_visibility_level,
      automatic_membership_email_domains: this.emailDomains,
      title: this.title,
      primary_group: !!this.primary_group,
      grant_trust_level: this.grant_trust_level,
      incoming_email: this.incoming_email,
      smtp_server: this.smtp_server,
      smtp_port: this.smtp_port,
      smtp_ssl_mode: this.smtp_ssl_mode,
      smtp_enabled: this.smtp_enabled,
      imap_server: this.imap_server,
      imap_port: this.imap_port,
      imap_ssl: this.imap_ssl,
      imap_mailbox_name: this.imap_mailbox_name,
      imap_enabled: this.imap_enabled,
      email_username: this.email_username,
      email_from_alias: this.email_from_alias,
      email_password: this.email_password,
      flair_icon: null,
      flair_upload_id: null,
      flair_bg_color: this.flairBackgroundHexColor,
      flair_color: this.flairHexColor,
      bio_raw: this.bio_raw,
      public_admission: this.public_admission,
      public_exit: this.public_exit,
      allow_membership_requests: this.allow_membership_requests,
      full_name: this.full_name,
      default_notification_level: this.default_notification_level,
      membership_request_template: this.membership_request_template,
      publish_read_state: this.publish_read_state,
      allow_unknown_sender_topic_replies:
        this.allow_unknown_sender_topic_replies,
    };

    ["muted", "regular", "watching", "tracking", "watching_first_post"].forEach(
      (s) => {
        let prop =
          s === "watching_first_post"
            ? "watchingFirstPostCategories"
            : s + "Categories";

        let categories = this.get(prop);

        if (categories) {
          attrs[s + "_category_ids"] =
            categories.length > 0 ? categories.map((c) => c.get("id")) : [-1];
        }

        let tags = this.get(s + "_tags");

        if (tags) {
          attrs[s + "_tags"] = tags.length > 0 ? tags : [""];
        }
      }
    );

    let agIds = this.associated_group_ids;
    if (agIds) {
      attrs["associated_group_ids"] = agIds.length ? agIds : [null];
    }

    if (this.flair_type === "icon") {
      attrs["flair_icon"] = this.flair_icon;
    } else if (this.flair_type === "image") {
      attrs["flair_upload_id"] = this.flair_upload_id;
    }

    if (!this.id) {
      attrs["usernames"] = this.usernames;
      attrs["owner_usernames"] = this.ownerUsernames;
    }

    return attrs;
  }

  async create() {
    const response = await ajax("/admin/groups", {
      type: "POST",
      data: { group: this.asJSON() },
    });

    this.setProperties({
      id: response.basic_group.id,
      usernames: null,
      ownerUsernames: null,
    });

    await this.reloadMembers();
  }

  save(opts = {}) {
    return ajax(`/groups/${this.id}`, {
      type: "PUT",
      data: { group: this.asJSON(), ...opts },
    });
  }

  destroy() {
    if (!this.id) {
      return;
    }
    return ajax(`/admin/groups/${this.id}`, { type: "DELETE" });
  }

  findLogs(offset, filters) {
    return ajax(`/groups/${this.name}/logs.json`, {
      data: { offset, filters },
    }).then((results) => {
      return EmberObject.create({
        logs: results["logs"].map((log) => GroupHistory.create(log)),
        all_loaded: results["all_loaded"],
      });
    });
  }

  async findPosts(opts) {
    opts = opts || {};
    const type = opts.type || "posts";
    const data = {};

    if (opts.before) {
      data.before = opts.before;
    }

    if (opts.categoryId) {
      data.category_id = parseInt(opts.categoryId, 10);
    }

    const result = await ajax(`/groups/${this.name}/${type}.json`, { data });

    result.categories?.forEach((category) => {
      Site.current().updateCategory(category);
    });

    return result.posts.map((p) => {
      p.user = User.create(p.user);
      p.topic = Topic.create(p.topic);
      p.category = Category.findById(p.category_id);
      return EmberObject.create(p);
    });
  }

  setNotification(notification_level, userId) {
    this.set("group_user.notification_level", notification_level);
    return ajax(`/groups/${this.name}/notifications`, {
      data: { notification_level, user_id: userId },
      type: "POST",
    });
  }

  requestMembership(reason) {
    return ajax(`/groups/${this.name}/request_membership.json`, {
      type: "POST",
      data: { reason },
    });
  }
}
