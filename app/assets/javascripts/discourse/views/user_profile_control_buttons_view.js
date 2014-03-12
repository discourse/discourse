/**
 This view is used for rendering the control buttons at the user profile

 @class UserProfileControlButtonsView
 @extends Discourse.ContainerView
 @namespace Discourse
 @module Discourse
 **/
Discourse.UserProfileControlButtonsView = Discourse.ContainerView.extend({
  //elementId: 'user-profile-control-buttons',

  init: function() {
    this._super();
    this.createButtons();
  },

  // Add the control buttons in the user profile
  createButtons: function() {
    var user = this.get('user');
    var currentUser = Discourse.User.current();
    if (currentUser) {
      if((user.id != currentUser.id)){
        if (user.can_send_private_message_to_user){
          this.attachViewClass(Discourse.PrivateMessageButton);
        }
      }

      if (user.id == currentUser.id){
        this.attachViewClass(Discourse.LogoutButton);
      }

      if(currentUser.staff){
        this.attachViewClass(Discourse.AdminAreaButton);
      }

      if(user.can_edit){
        this.attachViewClass(Discourse.UserPreferencesButton);
      }

//      this.trigger('additionalButtons', this);
    }

    this.attachViewClass(Discourse.UserInvitedButton);
  }
});