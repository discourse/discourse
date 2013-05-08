Discourse.Group = Discourse.Model.extend({
  userCountDisplay: function(){
    var c = this.get('user_count');
    // don't display zero its ugly
    if(c > 0) {
      return c;
    }
  }.property('user_count'),

  loadUsers: function() {
    var group = this;

    Discourse.ajax('/admin/groups/' + this.get('id') + '/users').then(function(payload){
      var users = Em.A()
      payload.each(function(user){
        users.addObject(Discourse.User.create(user));
      });
      group.set('users', users)
    });
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
  }.property('users')

});

Discourse.Group.reopenClass({
  findAll: function(){
    var list = Discourse.SelectableArray.create();

    Discourse.ajax("/admin/groups").then(function(groups){
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
