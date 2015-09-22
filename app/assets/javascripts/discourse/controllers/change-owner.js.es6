import SelectedPostsCount from 'discourse/mixins/selected-posts-count';
import ModalFunctionality from 'discourse/mixins/modal-functionality';
import DiscourseURL from 'discourse/lib/url';

// Modal related to changing the ownership of posts
export default Ember.Controller.extend(SelectedPostsCount, ModalFunctionality, {
  needs: ['topic'],

  topicController: Em.computed.alias('controllers.topic'),
  selectedPosts: Em.computed.alias('topicController.selectedPosts'),
  saving: false,
  new_user: null,

  buttonDisabled: function() {
    if (this.get('saving')) return true;
    return Ember.isEmpty(this.get('new_user'));
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

      Discourse.Topic.changeOwners(this.get('topicController.model.id'), saveOpts).then(function() {
        // success
        self.send('closeModal');
        self.get('topicController').send('toggleMultiSelect');
        Em.run.next(() => { DiscourseURL.routeTo(self.get("topicController.model.url")); });
      }, function() {
        // failure
        self.flash(I18n.t('topic.change_owner.error'), 'alert-error');
        self.set('saving', false);
      });
      return false;
    }
  }
});
