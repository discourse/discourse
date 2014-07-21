Discourse.Model = Ember.Object.extend(Discourse.Presence, {
  // Like `setProperties` but returns the original values in case
  // we want to roll back
  setPropertiesBackup: function(obj) {
    var backup = this.getProperties(Ember.keys(obj));
    this.setProperties(obj);
    return backup;
  }
});

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
