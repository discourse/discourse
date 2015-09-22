const Group = Discourse.Model.extend({
  limit: 50,
  offset: 0,
  user_count: 0,

  emailDomains: function() {
    var value = this.get("automatic_membership_email_domains");
    return Em.isEmpty(value) ? "" : value;
  }.property("automatic_membership_email_domains"),

  type: function() {
    return this.get("automatic") ? "automatic" : "custom";
  }.property("automatic"),

  userCountDisplay: function(){
    var c = this.get('user_count');
    // don't display zero its ugly
    if (c > 0) { return c; }
  }.property('user_count'),

  findMembers() {
    if (Em.isEmpty(this.get('name'))) { return ; }

    const self = this, offset = Math.min(this.get("user_count"), Math.max(this.get("offset"), 0));

    return Discourse.Group.loadMembers(this.get("name"), offset, this.get("limit")).then(function (result) {
      self.setProperties({
        user_count: result.meta.total,
        limit: result.meta.limit,
        offset: result.meta.offset,
        members: result.members.map(member => Discourse.User.create(member))
      });
    });
  },

  removeMember(member) {
    var self = this;
    return Discourse.ajax('/admin/groups/' + this.get('id') + '/members.json', {
      type: "DELETE",
      data: { user_id: member.get("id") }
    }).then(function() {
      // reload member list
      self.findMembers();
    });
  },

  addMembers(usernames) {
    var self = this;
    return Discourse.ajax('/admin/groups/' + this.get('id') + '/members.json', {
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
      grant_trust_level: this.get('grant_trust_level')
    };
  },

  create() {
    var self = this;
    return Discourse.ajax("/admin/groups", { type: "POST", data: this.asJSON() }).then(function(resp) {
      self.set('id', resp.basic_group.id);
    });
  },

  save() {
    return Discourse.ajax("/admin/groups/" + this.get('id'), { type: "PUT", data: this.asJSON() });
  },

  destroy() {
    if (!this.get('id')) { return; }
    return Discourse.ajax("/admin/groups/" + this.get('id'), { type: "DELETE" });
  },

  findPosts(opts) {
    opts = opts || {};

    var data = {};
    if (opts.beforePostId) { data.before_post_id = opts.beforePostId; }

    return Discourse.ajax("/groups/" + this.get('name') + "/posts.json", { data: data }).then(function (posts) {
      return posts.map(function (p) {
        p.user = Discourse.User.create(p.user);
        return Em.Object.create(p);
      });
    });
  }
});

Group.reopenClass({
  findAll(opts) {
    return Discourse.ajax("/admin/groups.json", { data: opts }).then(function (groups){
      return groups.map(g => Discourse.Group.create(g));
    });
  },

  findGroupCounts(name) {
    return Discourse.ajax("/groups/" + name + "/counts.json").then(result => Em.Object.create(result.counts));
  },

  find(name) {
    return Discourse.ajax("/groups/" + name + ".json").then(result => Discourse.Group.create(result.basic_group));
  },

  loadMembers(name, offset, limit) {
    return Discourse.ajax('/groups/' + name + '/members.json', {
      data: {
        limit: limit || 50,
        offset: offset || 0
      }
    });
  }
});

export default Group;
