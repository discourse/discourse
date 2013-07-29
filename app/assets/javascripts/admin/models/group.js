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
        var users = Em.A();
        _.each(payload,function(user){
          users.addObject(Discourse.User.create(user));
        });
        group.set('users', users);
        group.set('loaded', true);
      });
    }
  },

  usernames: function() {
    var users = this.get('users');
    var usernames = "";
    if(users) {
      usernames = _.map(users, function(user){
        return user.get('username');
      }).join(',');
    }
    return usernames;
  }.property('users'),

  destroy: function(){
    if(!this.id) return;

    var group = this;
    group.set('disableSave', true);

    return Discourse.ajax("/admin/groups/" + group.get('id'), {type: "DELETE"})
      .then(function(){
        return true;
      }, function(error) {
        group.set('disableSave', false);
        bootbox.alert(I18n.t("admin.groups.delete_failed"));
        return false;
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
    }}).then(function(resp) {
      group.set('disableSave', false);
      group.set('id', resp.id);
    }, function (error) {
      group.set('disableSave', false);
      if (error && error.responseText) {
        bootbox.alert($.parseJSON(error.responseText).errors);
      }
      else {
        bootbox.alert(I18n.t('generic_error'));
      }
    });
  },

  save: function(){
    var group = this;
    group.set('disableSave', true);

    return Discourse.ajax("/admin/groups/" + this.get('id'), {
      type: "PUT",
      data: {
        group: {
          name: this.get('name'),
          usernames: this.get('usernames')
        }
      },
      complete: function(){
        group.set('disableSave', false);
      }
    }).then(null, function(e){
      var message = $.parseJSON(e.responseText).errors;
      bootbox.alert(message);
    });
  }

});

Discourse.Group.reopenClass({
  findAll: function(){
    var list = Discourse.SelectableArray.create();

    Discourse.ajax("/admin/groups.json").then(function(groups){
      _.each(groups,function(group){
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
