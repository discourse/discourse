/**
  Modal related to changing the ownership of posts

  @class ChangeOwnerController
  @extends Discourse.ObjectController
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
 **/
export default Discourse.ObjectController.extend(Discourse.SelectedPostsCount, Discourse.ModalFunctionality, {
  needs: ['topic'],

  topicController: Em.computed.alias('controllers.topic'),
  selectedPosts: Em.computed.alias('topicController.selectedPosts'),

  buttonDisabled: function() {
    if (this.get('saving')) return true;
    return this.blank('new_user');
  }.property('saving', 'new_user'),

  buttonTitle: function() {
    if (this.get('saving')) return I18n.t('saving');
    return I18n.t('topic.change_owner.action');
  }.property('saving'),

  onShow: function() {
    this.setProperties({
      saving: false,
      new_user: ''
    });
  },

  actions: {
    changeOwnershipOfPosts: function() {
      this.set('saving', true);

      var postIds = this.get('selectedPosts').map(function(p) { return p.get('id'); }),
          self = this,
          saveOpts = {
            post_ids: postIds,
            username: this.get('new_user')
          };

      Discourse.Topic.changeOwners(this.get('id'), saveOpts).then(function(result) {
        // success
        self.send('closeModal');
        self.get('topicController').send('toggleMultiSelect');
        Em.run.next(function() { Discourse.URL.routeTo(result.url); });
      }, function() {
        // failure
        self.flash(I18n.t('topic.change_owner.error'), 'alert-error');
        self.set('saving', false);
      });
      return false;
    }
  }
});
