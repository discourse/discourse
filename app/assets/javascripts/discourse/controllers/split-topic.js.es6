import SelectedPostsCount from 'discourse/mixins/selected-posts-count';
import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { extractError } from 'discourse/lib/ajax-error';
import { movePosts } from 'discourse/models/topic';
import DiscourseURL from 'discourse/lib/url';

// Modal related to auto closing of topics
export default Ember.Controller.extend(SelectedPostsCount, ModalFunctionality, {
  needs: ['topic'],
  topicName: null,
  saving: false,
  categoryId: null,

  topicController: Em.computed.alias('controllers.topic'),
  selectedPosts: Em.computed.alias('topicController.selectedPosts'),
  selectedReplies: Em.computed.alias('topicController.selectedReplies'),
  allPostsSelected: Em.computed.alias('topicController.allPostsSelected'),

  buttonDisabled: function() {
    if (this.get('saving')) return true;
    return Ember.isEmpty(this.get('topicName'));
  }.property('saving', 'topicName'),

  buttonTitle: function() {
    if (this.get('saving')) return I18n.t('saving');
    return I18n.t('topic.split_topic.action');
  }.property('saving'),

  onShow() {
    this.setProperties({
      'controllers.modal.modalClass': 'split-modal',
      saving: false,
      categoryId: null,
      topicName: ''
    });
  },

  actions: {
    movePostsToNewTopic() {
      this.set('saving', true);

      const postIds = this.get('selectedPosts').map(function(p) { return p.get('id'); }),
            replyPostIds = this.get('selectedReplies').map(function(p) { return p.get('id'); }),
            self = this,
            categoryId = this.get('categoryId'),
            saveOpts = {
              title: this.get('topicName'),
              post_ids: postIds,
              reply_post_ids: replyPostIds
            };

      if (!Ember.isNone(categoryId)) { saveOpts.category_id = categoryId; }

      movePosts(this.get('model.id'), saveOpts).then(function(result) {
        // Posts moved
        self.send('closeModal');
        self.get('topicController').send('toggleMultiSelect');
        Ember.run.next(function() { DiscourseURL.routeTo(result.url); });
      }).catch(function(xhr) {
        self.flash(extractError(xhr, I18n.t('topic.split_topic.error')));
      }).finally(function() {
        self.set('saving', false);
      });
      return false;
    }
  }


});
