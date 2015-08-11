import ModalFunctionality from 'discourse/mixins/modal-functionality';

export default Ember.Controller.extend(ModalFunctionality, {

  submitDisabled: function() {
    return (!this.get('reason') || this.get('reason').length < 1);
  }.property('reason'),

  actions: {
    suspend: function() {
      if (this.get('submitDisabled')) return;
      var duration = parseInt(this.get('duration'), 10);
      if (duration > 0) {
        var self = this;
        this.send('hideModal');
        this.get('model').suspend(duration, this.get('reason')).then(function() {
          window.location.reload();
        }, function(e) {
          var error = I18n.t('admin.user.suspend_failed', { error: "http: " + e.status + " - " + e.body });
          bootbox.alert(error, function() { self.send('reopenModal'); });
        });
      }
    }
  }

});
