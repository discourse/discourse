/**
  Represents a user's stream

  @class UserStream
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.UserStream = Discourse.Model.extend({

  filterChanged: function() {
    this.setProperties({
      content: Em.A(),
      itemsLoaded: 0
    });
    this.findItems();
  }.observes('filter'),

  findItems: function() {
    var me = this;
    if(this.get("loading")) { return; }
    this.set("loading",true);

    var url = Discourse.getURL("/user_actions.json?offset=") + this.get('itemsLoaded') + "&username=" + (this.get('user.username_lower'));
    if (this.get('filter')) {
      url += "&filter=" + (this.get('filter'));
    }

    var stream = this;
    return Discourse.ajax(url, {cache: 'false'}).then( function(result) {
      me.set("loading",false);
      if (result && result.user_actions) {
        var copy = Em.A();
        _.each(result.user_actions,function(action) {
          copy.pushObject(Discourse.UserAction.create(action));
        });
        copy = Discourse.UserAction.collapseStream(copy);
        stream.get('content').pushObjects(copy);
        stream.set('itemsLoaded', stream.get('itemsLoaded') + result.user_actions.length);
      }
    }, function(){ me.set("loading", false); });
  }

});
