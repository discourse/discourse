/**
 A button for admin area

 @class AdminAreaButton
 @extends Discourse.ButtonView
 @namespace Discourse
 @module Discourse
 **/
Discourse.AdminAreaButton = Discourse.ButtonView.extend({
  classNames: ['right'],
  textKey: 'admin.user.show_admin_profile',

  click: function(){
    Discourse.URL.routeTo(Discourse.User.current().get('adminPath'));
  },

  renderIcon: function(buffer) {
    buffer.push("<i class='fa fa-wrench'></i>");
  }
});