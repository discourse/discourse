export default Ember.Controller.extend({
  editing: false,
  savedIpAddress: null,

  isRange: function() {
    return this.get("model.ip_address").indexOf("/") > 0;
  }.property("model.ip_address"),

  actions: {
    allow: function(record) {
      record.set('action_name', 'do_nothing');
      this.send('save', record);
    },

    block: function(record) {
      record.set('action_name', 'block');
      this.send('save', record);
    },

    edit: function() {
      if (!this.get('editing')) {
        this.savedIpAddress = this.get('model.ip_address');
      }
      this.set('editing', true);
    },

    cancel: function() {
      if (this.get('savedIpAddress') && this.get('editing')) {
        this.set('model.ip_address', this.get('savedIpAddress'));
      }
      this.set('editing', false);
    },

    save: function(record) {
      var self = this;
      var wasEditing = this.get('editing');
      this.set('editing', false);
      record.save().then(function(saved){
        if (saved.success) {
          self.set('savedIpAddress', null);
        } else {
          bootbox.alert(saved.errors);
          if (wasEditing) self.set('editing', true);
        }
      }, function(e){
        if (e.responseJSON && e.responseJSON.errors) {
          bootbox.alert(I18n.t("generic_error_with_reason", {error: e.responseJSON.errors.join('. ')}));
        } else {
          bootbox.alert(I18n.t("generic_error"));
        }
        if (wasEditing) self.set('editing', true);
      });
    },

    destroy: function(record) {
      var self = this;
      return bootbox.confirm(I18n.t("admin.logs.screened_ips.delete_confirm", {ip_address: record.get('ip_address')}), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          record.destroy().then(function(deleted) {
            if (deleted) {
              self.get("parentController.content").removeObject(record);
            } else {
              bootbox.alert(I18n.t("generic_error"));
            }
          }, function(e){
            bootbox.alert(I18n.t("generic_error_with_reason", {error: "http: " + e.status + " - " + e.body}));
          });
        }
      });
    }
  }
});
