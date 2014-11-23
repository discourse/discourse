import ModalFunctionality from 'discourse/mixins/modal-functionality';
import ObjectController from 'discourse/controllers/object';

// Modal related to auto closing of topics
export default ObjectController.extend(ModalFunctionality, {
  auto_close_valid: true,
  auto_close_invalid: Em.computed.not('auto_close_valid'),

  setAutoCloseTime: function() {
    var autoCloseTime = null;

    if (this.get("details.auto_close_based_on_last_post")) {
      autoCloseTime = this.get("details.auto_close_hours");
    } else if (this.get("details.auto_close_at")) {
      var closeTime = new Date(this.get("details.auto_close_at"));
      if (closeTime > new Date()) {
        autoCloseTime = moment(closeTime).format("YYYY-MM-DD HH:mm");
      }
    }

    this.set("auto_close_time", autoCloseTime);
  }.observes("details.{auto_close_at,auto_close_hours}"),

  actions: {
    saveAutoClose: function() { this.setAutoClose(this.get("auto_close_time")); },
    removeAutoClose: function() { this.setAutoClose(null); }
  },

  setAutoClose: function(time) {
    var self = this;
    this.send('hideModal');
    Discourse.ajax({
      url: '/t/' + this.get('id') + '/autoclose',
      type: 'PUT',
      dataType: 'json',
      data: {
        auto_close_time: time,
        auto_close_based_on_last_post: this.get("details.auto_close_based_on_last_post"),
      }
    }).then(function(result){
      if (result.success) {
        self.send('closeModal');
        self.set('details.auto_close_at', result.auto_close_at);
        self.set('details.auto_close_hours', result.auto_close_hours);
      } else {
        bootbox.alert(I18n.t('composer.auto_close.error'), function() { self.send('showModal'); } );
      }
    }, function () {
      bootbox.alert(I18n.t('composer.auto_close.error'), function() { self.send('showModal'); } );
    });
  }

});
