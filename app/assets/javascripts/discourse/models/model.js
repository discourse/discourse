Discourse.Model = Ember.Object.extend(Discourse.Presence);

Discourse.Model.reopenClass({
  extractByKey: function(collection, klass) {
    var retval = {};
    if (Ember.isEmpty(collection)) { return retval; }

    collection.forEach(function(item) {
      retval[item.id] = klass.create(item);
    });
    return retval;
  }
});
