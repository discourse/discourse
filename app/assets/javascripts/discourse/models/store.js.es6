export default Ember.Object.extend({
  findAll(type) {
    const adapter = this.container.lookup('adapter:' + type) || this.container.lookup('adapter:rest');
    return adapter.findAll(type);
  }
});
