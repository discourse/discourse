/**
  This controller supports actions related to flagging

  @class FlagController
  @extends Discourse.ObjectController
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.FlagController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

  changePostActionType: function(action) {
    this.set('selected', action);
  },

  submitEnabled: function() {
    var selected = this.get('selected');
    if (!selected) return false;

    if (selected.get('is_custom_flag')) {
      var len = this.get('message.length') || 0;
      return len >= Discourse.PostActionType.MIN_MESSAGE_LENGTH &&
             len <= Discourse.PostActionType.MAX_MESSAGE_LENGTH;
    }
    return true;
  }.property('selected.is_custom_flag', 'message.length'),

  submitDisabled: Em.computed.not('submitEnabled'),

  // Staff accounts can "take action"
  canTakeAction: function() {
    // We can only take actions on non-custom flags
    if (this.get('selected.is_custom_flag')) return false;
    return Discourse.User.current('staff');
  }.property('selected.is_custom_flag'),

  submitText: function(){
    if (this.get('selected.is_custom_flag')) {
      return Em.String.i18n("flagging.notify_action");
    } else {
      return Em.String.i18n("flagging.action");
    }
  }.property('selected.is_custom_flag'),

  takeAction: function() {
    this.createFlag({takeAction: true})
    this.set('hidden', true);
  },

  createFlag: function(opts) {
    var flagController = this;
    var postAction = this.get('actionByName.' + this.get('selected.name_key'));
    var params = this.get('selected.is_custom_flag') ? {message: this.get('message')} : {}

    if (opts) params = $.extend(params, opts);

    postAction.act(params).then(function() {
      flagController.closeModal();
    }, function(errors) {
      flagController.displayErrors(errors);
    });
  }

});


