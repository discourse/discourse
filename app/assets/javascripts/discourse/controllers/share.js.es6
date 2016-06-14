import Sharing from 'discourse/lib/sharing';
import { longDateNoYear } from 'discourse/lib/formatter';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  needs: ['topic'],

  title: Ember.computed.alias('controllers.topic.model.title'),
  canReplyAsNewTopic: Ember.computed.alias('controllers.topic.model.details.can_reply_as_new_topic'),

  @computed('type', 'postNumber')
  shareTitle(type, postNumber) {
    if (type === 'topic') { return I18n.t('share.topic'); }
    if (postNumber) {
      return I18n.t('share.post', { postNumber });
    } else {
      return I18n.t('share.topic');
    }
  },

  @computed('date')
  displayDate(date) {
    return longDateNoYear(new Date(date));
  },

  // Close the share controller
  actions: {
    close() {
      this.setProperties({ link: '', postNumber: '' });
      return false;
    },

    replyAsNewTopic() {
      const topicController = this.get("controllers.topic");
      const postStream = topicController.get("model.postStream");
      const postId = postStream.findPostIdForPostNumber(this.get("postNumber"));
      const post = postStream.findLoadedPost(postId);
      topicController.send("replyAsNewTopic", post);
      this.send("close");
    },

    share(source) {
      var url = source.generateUrl(this.get('link'), this.get('title'));
      if (source.shouldOpenInPopup) {
        window.open(url, '', 'menubar=no,toolbar=no,resizable=yes,scrollbars=yes,width=600,height=' + (source.popupHeight || 315));
      } else {
        window.open(url, '_blank');
      }
    }
  },

  @computed
  sources() {
    return Sharing.activeSources(this.siteSettings.share_links);
  }
});
