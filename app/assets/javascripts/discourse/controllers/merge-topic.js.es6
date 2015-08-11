import SelectedPostsCount from 'discourse/mixins/selected-posts-count';
import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { movePosts, mergeTopic } from 'discourse/models/topic';
import DiscourseURL from 'discourse/lib/url';

// Modal related to merging of topics
export default Ember.Controller.extend(SelectedPostsCount, ModalFunctionality, {
  needs: ['topic'],

  saving: false,
  selectedTopicId: null,

  topicController: Em.computed.alias('controllers.topic'),
  selectedPosts: Em.computed.alias('topicController.selectedPosts'),
  selectedReplies: Em.computed.alias('topicController.selectedReplies'),
  allPostsSelected: Em.computed.alias('topicController.allPostsSelected'),

  buttonDisabled: function() {
    if (this.get('saving')) return true;
    return Ember.isEmpty(this.get('selectedTopicId'));
  }.property('selectedTopicId', 'saving'),

  buttonTitle: function() {
    if (this.get('saving')) return I18n.t('saving');
    return I18n.t('topic.merge_topic.title');
  }.property('saving'),

  onShow() {
    this.set('controllers.modal.modalClass', 'split-modal');
  },

  actions: {
    movePostsToExistingTopic() {
      const topicId = this.get('model.id');

      this.set('saving', true);

      let promise = null;
      if (this.get('allPostsSelected')) {
        promise = mergeTopic(topicId, this.get('selectedTopicId'));
      } else {
        const postIds = this.get('selectedPosts').map(function(p) { return p.get('id'); });
        const replyPostIds = this.get('selectedReplies').map(function(p) { return p.get('id'); });

        promise = movePosts(topicId, {
          destination_topic_id: this.get('selectedTopicId'),
          post_ids: postIds,
          reply_post_ids: replyPostIds
        });
      }

      const self = this;
      promise.then(function(result) {
        // Posts moved
        self.send('closeModal');
        self.get('topicController').send('toggleMultiSelect');
        Em.run.next(function() { DiscourseURL.routeTo(result.url); });
      }).catch(function() {
        self.flash(I18n.t('topic.merge_topic.error'));
      }).finally(function() {
        self.set('saving', false);
      });
      return false;
    }
  }

});
