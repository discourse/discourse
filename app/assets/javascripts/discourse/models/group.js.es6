import { ajax } from 'discourse/lib/ajax';
import { default as computed, observes } from "ember-addons/ember-computed-decorators";
import GroupHistory from 'discourse/models/group-history';
import RestModel from 'discourse/models/rest';
import { popupAjaxError } from 'discourse/lib/ajax-error';

const Group = RestModel.extend({
  limit: 50,
  offset: 0,
  user_count: 0,
  owners: [],

  hasOwners: Ember.computed.notEmpty('owners'),

  @computed("automatic_membership_email_domains")
  emailDomains(value) {
    return Em.isEmpty(value) ? "" : value;
  },

  type: function() {
    return this.get("automatic") ? "automatic" : "custom";
  }.property("automatic"),

  @computed('user_count')
  userCountDisplay(userCount) {
    // don't display zero its ugly
    if (userCount > 0) { return userCount; }
  },

  findMembers(params) {
    if (Em.isEmpty(this.get('name'))) { return ; }

    const self = this, offset = Math.min(this.get("user_count"), Math.max(this.get("offset"), 0));

    return Group.loadMembers(this.get("name"), offset, this.get("limit"), params).then(function (result) {
      var ownerIds = {};
      result.owners.forEach(owner => ownerIds[owner.id] = true);

      self.setProperties({
        user_count: result.meta.total,
        limit: result.meta.limit,
        offset: result.meta.offset,
        members: result.members.map(member => {
          if (ownerIds[member.id]) {
            member.owner = true;
          }
          return Discourse.User.create(member);
        }),
        owners: result.owners.map(owner => Discourse.User.create(owner)),
      });
    });
  },

  removeOwner(member) {
    var self = this;
    return ajax('/admin/groups/' + this.get('id') + '/owners.json', {
      type: "DELETE",
      data: { user_id: member.get("id") }
    }).then(function() {
      // reload member list
      self.findMembers();
    });
  },

  removeMember(member) {
    var self = this;
    return ajax('/groups/' + this.get('id') + '/members.json', {
      type: "DELETE",
      data: { user_id: member.get("id") }
    }).then(function() {
      // reload member list
      self.findMembers();
    });
  },

  addMembers(usernames) {
    var self = this;
    return ajax('/groups/' + this.get('id') + '/members.json', {
      type: "PUT",
      data: { usernames: usernames }
    }).then(function() {
      self.findMembers();
    });
  },

  addOwners(usernames) {
    var self = this;
    return ajax('/admin/groups/' + this.get('id') + '/owners.json', {
      type: "PUT",
      data: { usernames: usernames }
    }).then(function() {
      self.findMembers();
    });
  },

  @computed('flair_bg_color')
  flairBackgroundHexColor() {
    return this.get('flair_bg_color') ? this.get('flair_bg_color').replace(new RegExp("[^0-9a-fA-F]", "g"), "") : null;
  },

  @computed('flair_color')
  flairHexColor() {
    return this.get('flair_color') ? this.get('flair_color').replace(new RegExp("[^0-9a-fA-F]", "g"), "") : null;
  },

  @computed('alias_level')
  canEveryoneMention(aliasLevel) {
    return aliasLevel === '99';
  },

  @observes("visible", "canEveryoneMention")
  _updateAllowMembershipRequests() {
    if (!this.get('visible') || !this.get('canEveryoneMention')) {
      this.set ('allow_membership_requests', false);
    }
  },

  @observes("visible")
  _updatePublic() {
    if (!this.get('visible')) this.set('public', false);
  },

  asJSON() {
    return {
      name: this.get('name'),
      alias_level: this.get('alias_level'),
      visible: !!this.get('visible'),
      automatic_membership_email_domains: this.get('emailDomains'),
      automatic_membership_retroactive: !!this.get('automatic_membership_retroactive'),
      title: this.get('title'),
      primary_group: !!this.get('primary_group'),
      grant_trust_level: this.get('grant_trust_level'),
      incoming_email: this.get("incoming_email"),
      flair_url: this.get('flair_url'),
      flair_bg_color: this.get('flairBackgroundHexColor'),
      flair_color: this.get('flairHexColor'),
      bio_raw: this.get('bio_raw'),
      public: this.get('public'),
      allow_membership_requests: this.get('allow_membership_requests'),
      full_name: this.get('full_name')
    };
  },

  create() {
    var self = this;
    return ajax("/admin/groups", { type: "POST", data:  { group: this.asJSON() } }).then(function(resp) {
      self.set('id', resp.basic_group.id);
    });
  },

  save() {
    const id = this.get('id');
    const url = this.get('is_group_owner') ? `/groups/${id}` : `/admin/groups/${id}`;

    return ajax(url, {
      type: "PUT",
      data: { group: this.asJSON() }
    });
  },

  destroy() {
    if (!this.get('id')) { return; }
    return ajax("/admin/groups/" + this.get('id'), { type: "DELETE" });
  },

  findLogs(offset, filters) {
    return ajax(`/groups/${this.get('name')}/logs.json`, { data: { offset, filters } }).then(results => {
      return Ember.Object.create({
        logs: results["logs"].map(log => GroupHistory.create(log)),
        all_loaded: results["all_loaded"]
      });
    });
  },

  findPosts(opts) {
    opts = opts || {};

    const type = opts['type'] || 'posts';

    var data = {};
    if (opts.beforePostId) { data.before_post_id = opts.beforePostId; }

    return ajax(`/groups/${this.get('name')}/${type}.json`, { data: data }).then(posts => {
      return posts.map(p => {
        p.user = Discourse.User.create(p.user);
        p.topic = Discourse.Topic.create(p.topic);
        return Em.Object.create(p);
      });
    });
  },

  setNotification(notification_level) {
    this.set("group_user.notification_level", notification_level);
    return ajax(`/groups/${this.get("name")}/notifications`, {
      data: { notification_level },
      type: "POST"
    });
  }
});

Group.reopenClass({
  findAll(opts) {
    return ajax("/admin/groups.json", { data: opts }).then(function (groups){
      return groups.map(g => Group.create(g));
    });
  },

  find(name) {
    return ajax("/groups/" + name + ".json").then(result => Group.create(result.basic_group));
  },

  loadOwners(name) {
    return ajax('/groups/' + name + '/owners.json').catch(popupAjaxError);
  },

  loadMembers(name, offset, limit, params) {
    return ajax('/groups/' + name + '/members.json', {
      data: _.extend({
        limit: limit || 50,
        offset: offset || 0
      }, params || {})
    });
  },

  mentionable(name) {
    return ajax(`/groups/${name}/mentionable`, { data: { name } });
  },
});

export default Group;
