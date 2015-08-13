export default Ember.Route.extend({
  model() {
    return Discourse.Backup.find();
  }
});
