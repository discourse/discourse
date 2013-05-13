/**
  This view handles a modal to set, edit, and remove a topic's auto-close time.

  @class EditTopicAutoCloseView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.EditTopicAutoCloseView = Discourse.ModalBodyView.extend({
  templateName: 'modal/auto_close',
  title: Em.String.i18n('topic.auto_close_title'),
  modalClass: 'edit-auto-close-modal',

  setDays: function() {
    if( this.get('topic.auto_close_at') ) {
      var closeTime = Date.create( this.get('topic.auto_close_at') );
      if (closeTime.isFuture()) {
        this.set('auto_close_days', closeTime.daysSince());
      }
    }
  }.observes('topic'),

  saveAutoClose: function() {
    this.setAutoClose( parseFloat(this.get('auto_close_days')) );
  },

  removeAutoClose: function() {
    this.setAutoClose(null);
  },

  setAutoClose: function(days) {
    var view = this;
    Discourse.ajax({
      url: "/t/" + this.get('topic.id') + "/autoclose",
      type: 'PUT',
      dataType: 'json',
      data: { auto_close_days: days > 0 ? days : null }
    }).then(function(){
      view.get('topic').set('auto_close_at', Date.create(days + ' days from now').toJSON());
    }, function (error) {
      bootbox.alert(Em.String.i18n('generic_error'));
    });
  }

});