Discourse.Group = Discourse.Model.extend({
  loaded: false,

  userCountDisplay: function(){
    var c = this.get('user_count');
    // don't display zero its ugly
    if(c > 0) {
      return c;
    }
  }.property('user_count'),

  load: function() {
    var id = this.get('id');
    if(id && !this.get('loaded')) {
      var group = this;
      Discourse.ajax('/admin/groups/' + this.get('id') + '/users').then(function(payload){
        var users = Em.A()
        payload.each(function(user){
          users.addObject(Discourse.User.create(user));
        });
        group.set('users', users)
        group.set('loaded', true)
      });
    }
  },

  usernames: function() {
    var users = this.get('users');
    var usernames = "";
    if(users) {
      usernames = $.map(users, function(user){
        return user.get('username');
      }).join(',')
    }
    return usernames;
  }.property('users'),

  destroy: function(){
    var group = this;
    group.set('disableSave', true);

    return Discourse.ajax("/admin/groups/" + this.get("id"), {type: "DELETE"})
      .then(function(){
        group.set('disableSave', false);
      });
  },

  create: function(){
    var group = this;
    group.set('disableSave', true);

    return Discourse.ajax("/admin/groups", {type: "POST", data: {
      group: {
        name: this.get('name'),
        usernames: this.get('usernames')
      }
    }}).then(function(r){
      group.set('disableSave', false);
      group.set('id', r.id);
    });
  },


  save: function(){
    var group = this;
    group.set('disableSave', true);

    return Discourse.ajax("/admin/groups/" + this.get('id'), {type: "PUT", data: {
      group: {
        name: this.get('name'),
        usernames: this.get('usernames')
      }
    }}).then(function(r){
      group.set('disableSave', false);
    });
  }

});

Discourse.Group.reopenClass({
  findAll: function(){
    var list = Discourse.SelectableArray.create();

    Discourse.ajax("/admin/groups.json").then(function(groups){
      groups.each(function(group){
        list.addObject(Discourse.Group.create(group));
      });
    });

    return list;
  },

  find: function(id) {
    var promise = new Em.Deferred();

    setTimeout(function(){
      promise.resolve(Discourse.Group.create({id: 1, name: "all mods", members: ["A","b","c"]}));
    }, 1000);

    return promise;
  }
});
