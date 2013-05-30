/**
  This controller supports actions related to flagging

  @class FlagController
  @extends Discourse.ObjectController
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.FlagController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

  // trick to bind user / post to flag
  boundFlags: function() {
    var _this = this;
    var original = this.get('flagsAvailable');
    if(original){
      return $.map(original, function(v){
        var b = Discourse.BoundPostActionType.create(v);
        b.set('post', _this.get('model'));
        return b;
      });
    }
  }.property('flagsAvailable.@each'),

  changePostActionType: function(action) {
    if (this.get('postActionTypeId') === action.id) return false;

    this.get('boundFlags').setEach('selected', false);
    action.set('selected', true);

    this.set('postActionTypeId', action.id);
    this.set('isCustomFlag', action.is_custom_flag);
    this.set('selected', action);
    return false;
  },

  showSubmit: function() {
    if (this.get('postActionTypeId')) {
      if (this.get('isCustomFlag')) {
        var m = this.get('selected.message');
        return m && m.length >= 10 && m.length <= 500;
      } else {
        return true;
      }
    }
    return false;
  }.property('isCustomFlag', 'selected.customMessageLength', 'postActionTypeId'),

  submitText: function(){
    var action = this.get('selected');
    if (this.get('selected.is_custom_flag')) {
      return Em.String.i18n("flagging.notify_action");
    } else {
      return Em.String.i18n("flagging.action");
    }
  }.property('selected'),

  createFlag: function() {
    var _this = this;

    var action = this.get('selected');
    var postAction = this.get('actionByName.' + (action.get('name_key')));

    var actionType = Discourse.Site.instance().postActionTypeById(this.get('postActionTypeId'));
    if (postAction) {
      postAction.act({
        message: action.get('message')
      }).then(function() {
        return $('#discourse-modal').modal('hide');
      }, function(errors) {
        return _this.displayErrors(errors);
      });
    }
    return false;
  }
});


