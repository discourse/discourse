import debounce from 'discourse/lib/debounce';
import Permalink from 'admin/models/permalink';

export default Ember.ArrayController.extend({
  loading: false,
  filter: null,

  show: debounce(function() {
    var self = this;
    self.set('loading', true);
    Permalink.findAll(self.get("filter")).then(function(result) {
      self.set('model', result);
      self.set('loading', false);
    });
  }, 250).observes("filter"),

  actions: {
    recordAdded(arg) {
      this.get("model").unshiftObject(arg);
    },

    destroy: function(record) {
      const self = this;
      return bootbox.confirm(I18n.t("admin.permalink.delete_confirm"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          record.destroy().then(function(deleted) {
            if (deleted) {
              self.removeObject(record);
            } else {
              bootbox.alert(I18n.t("generic_error"));
            }
          }, function(){
            bootbox.alert(I18n.t("generic_error"));
          });
        }
      });
    }
  }
});
