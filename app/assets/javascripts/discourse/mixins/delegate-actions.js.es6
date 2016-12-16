export default Ember.Mixin.create({
  init() {
    this._super();
    (this.get('delegated') || []).forEach(m => this.set(m, m));
  },
});
