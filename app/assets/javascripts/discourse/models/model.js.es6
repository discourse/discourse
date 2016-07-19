const Model = Ember.Object.extend();

Model.reopenClass({
  extractByKey(collection, klass) {
    const retval = {};
    if (Ember.isEmpty(collection)) { return retval; }

    collection.forEach(function(item) {
      retval[item.id] = klass.create(item);
    });
    return retval;
  }
});

export default Model;
