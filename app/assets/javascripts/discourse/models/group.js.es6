import { ajax } from 'discourse/lib/ajax';
import computed from 'ember-addons/ember-computed-decorators';

const Group = Discourse.Model.extend({
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

  findMembers() {
    if (Em.isEmpty(this.get('name'))) { return ; }

    const self = this, offset = Math.min(this.get("user_count"), Math.max(this.get("offset"), 0));

    return Group.loadMembers(this.get("name"), offset, this.get("limit")).then(function (result) {
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
    };
  },

  create() {
    var self = this;
    return ajax("/admin/groups", { type: "POST", data: this.asJSON() }).then(function(resp) {
      self.set('id', resp.basic_group.id);
    });
  },

  save() {
    return ajax("/admin/groups/" + this.get('id'), { type: "PUT", data: this.asJSON() });
  },

  destroy() {
    if (!this.get('id')) { return; }
    return ajax("/admin/groups/" + this.get('id'), { type: "DELETE" });
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
    this.set("notification_level", notification_level);
    return ajax(`/groups/${this.get("name")}/notifications`, {
      data: { notification_level },
      type: "POST"
    });
  },
});

Group.reopenClass({
  findAll(opts) {
    return ajax("/admin/groups.json", { data: opts }).then(function (groups){
      return groups.map(g => Group.create(g));
    });
  },

  findGroupCounts(name) {
    return ajax("/groups/" + name + "/counts.json").then(result => Em.Object.create(result.counts));
  },

  find(name) {
    return ajax("/groups/" + name + ".json").then(result => Group.create(result.basic_group));
  },

  loadMembers(name, offset, limit) {
    return ajax('/groups/' + name + '/members.json', {
      data: {
        limit: limit || 50,
        offset: offset || 0
      }
    });
  }
});

export default Group;
