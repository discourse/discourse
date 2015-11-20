import Backup from 'admin/models/backup';

export default Ember.Route.extend({
  model() {
    return Backup.find();
  }
});
