/**
  This view handles the modal for flagging posts

  @class FlagView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.FlagView = Discourse.ModalBodyView.extend({
  templateName: 'flag',
  title: Em.String.i18n('flagging.title'),

  // trick to bind user / post to flag
  boundFlags: function(){
    var _this = this;
    var original = this.get('post.flagsAvailable');
    if(original){
      return $.map(original, function(v){
        var b = Discourse.BoundPostActionType.create(v);
        b.set('post', _this.get('post'));
        return b;
      });
    }
  }.property('post.flagsAvailable'),

  changePostActionType: function(action) {

    if (this.get('postActionTypeId') === action.id) return false;

    this.get('boundFlags').each(function(f){
      f.set('selected', false);
    });
    action.set('selected', true);

    this.set('postActionTypeId', action.id);
    this.set('isCustomFlag', action.is_custom_flag);
    this.set('selected', action);
    Em.run.next(function() {
      $('#radio_' + action.name_key).prop('checked', 'true');
    });
    return false;
  },

  createFlag: function() {
    var _this = this;

    var action = this.get('selected');
    var postAction = this.get('post.actionByName.' + (action.get('name_key')));

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
  },

  showSubmit: (function() {
    var m;
    if (this.get('postActionTypeId')) {
      if (this.get('isCustomFlag')) {
        m = this.get('selected.message');
        return m && m.length >= 10 && m.length <= 500;
      } else {
        return true;
      }
    }
    return false;
  }).property('isCustomFlag', 'selected.customMessageLength', 'postActionTypeId'),

  submitText: function(){
    var action = this.get('selected');
    if (this.get('selected.is_custom_flag')) {
      return Em.String.i18n("flagging.notify_action");
    } else {
      return Em.String.i18n("flagging.action");
    }
  }.property('selected'),

  didInsertElement: function() {
    this.set('postActionTypeId', null);

    // Would be nice if there were an EmberJs radio button to do this for us. Oh well, one should be coming
    // in an upcoming release.
    this.$("input[type='radio']").prop('checked', false);
  }
});
