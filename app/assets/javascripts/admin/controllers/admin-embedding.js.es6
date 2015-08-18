export default Ember.Controller.extend({
  embedding: null,

  actions: {
    saveChanges() {
      this.get('embedding').update({});
    },

    addHost() {
      const host = this.store.createRecord('embeddable-host');
      this.get('embedding.embeddable_hosts').pushObject(host);
    },

    deleteHost(host) {
      this.get('embedding.embeddable_hosts').removeObject(host);
    }
  }
});
