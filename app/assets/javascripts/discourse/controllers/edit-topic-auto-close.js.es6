/**
  Modal related to auto closing of topics

  @class EditTopicAutoCloseController
  @extends Discourse.ObjectController
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
export default Discourse.ObjectController.extend(Discourse.ModalFunctionality, {
  auto_close_valid: true,
  auto_close_invalid: Em.computed.not('auto_close_valid'),

  setAutoCloseTime: function() {
    if( this.get('details.auto_close_at') ) {
      var closeTime = new Date( this.get('details.auto_close_at') );
      if (closeTime > new Date()) {
        this.set('auto_close_time', moment(closeTime).format("YYYY-MM-DD HH:mm"));
      }
    } else {
      this.set('details.auto_close_time', '');
    }
  }.observes('details.auto_close_at'),

  actions: {
    saveAutoClose: function() {
      this.setAutoClose( this.get('auto_close_time') );
    },

    removeAutoClose: function() {
      this.setAutoClose(null);
    }
  },

  setAutoClose: function(time) {
    var self = this;
    this.send('hideModal');
    Discourse.ajax({
      url: '/t/' + this.get('id') + '/autoclose',
      type: 'PUT',
      dataType: 'json',
      data: { auto_close_time: Discourse.Utilities.timestampFromAutocloseString(time) }
    }).then(function(result){
      if (result.success) {
        self.send('closeModal');
        self.set('details.auto_close_at', result.auto_close_at);
      } else {
        bootbox.alert(I18n.t('composer.auto_close_error'), function() { self.send('showModal'); } );
      }
    }, function () {
      bootbox.alert(I18n.t('composer.auto_close_error'), function() { self.send('showModal'); } );
    });
  }

});
