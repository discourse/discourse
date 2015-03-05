export default Ember.Object.extend({
  findAll(type) {
    const adapter = this.container.lookup('adapter:' + type) || this.container.lookup('adapter:rest');
    return adapter.findAll(type);
  },

  find(type, id) {
    const adapter = this.container.lookup('adapter:' + type) || this.container.lookup('adapter:rest');
    return adapter.find(type, id);
  },

  createRecord(type, attrs) {
    const adapter = this.container.lookup('adapter:' + type) || this.container.lookup('adapter:rest');
    return adapter.createRecord(type, attrs);
  }
});
