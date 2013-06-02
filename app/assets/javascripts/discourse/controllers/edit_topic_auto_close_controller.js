/**
  Modal related to auto closing of topics

  @class EditTopicAutoCloseController
  @extends Discourse.ObjectController
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.EditTopicAutoCloseController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

  setDays: function() {
    if( this.get('auto_close_at') ) {
      var closeTime = Date.create( this.get('auto_close_at') );
      if (closeTime.isFuture()) {
        this.set('auto_close_days', closeTime.daysSince());
      }
    } else {
      this.set('auto_close_days', "");
    }
  }.observes('auto_close_at'),

  saveAutoClose: function() {
    this.setAutoClose( parseFloat(this.get('auto_close_days')) );
  },

  removeAutoClose: function() {
    this.setAutoClose(null);
  },

  setAutoClose: function(days) {
    var editTopicAutoCloseController = this;
    Discourse.ajax({
      url: "/t/" + this.get('id') + "/autoclose",
      type: 'PUT',
      dataType: 'json',
      data: { auto_close_days: days > 0 ? days : null }
    }).then(function(){
      editTopicAutoCloseController.set('auto_close_at', Date.create(days + ' days from now').toJSON());
    }, function (error) {
      bootbox.alert(Em.String.i18n('generic_error'));
    });
  }

});