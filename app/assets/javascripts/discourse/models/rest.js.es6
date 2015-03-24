export default Ember.Object.extend({
  update(attrs) {
    const self = this,
          type = this.get('__type');
    return this.store.update(type, this.get('id'), attrs).then(function(result) {
      if (result && result[type]) {
        Object.keys(result).forEach(function(k) {
          attrs[k] = result[k];
        });
      }
      self.setProperties(attrs);
      return result;
    });
  },

  destroyRecord() {
    const type = this.get('__type');
    return this.store.destroyRecord(type, this);
  }
});
