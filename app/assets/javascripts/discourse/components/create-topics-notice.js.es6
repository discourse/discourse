import computed from 'ember-addons/ember-computed-decorators';
import { observes } from 'ember-addons/ember-computed-decorators';
import LivePostCounts from 'discourse/models/live-post-counts';

export default Ember.Component.extend({
  classNameBindings: ['hidden:hidden',':create-topics-notice'],

  enabled: false,

  publicTopicCount: null,
  publicPostCount: null,

  requiredTopics: 5,
  requiredPosts: Ember.computed.alias('siteSettings.tl1_requires_read_posts'),

  init() {
    this._super();
    if (this.get('shouldSee')) {
      let topicCount = 0,
          postCount = 0;

      // Use data we already have before fetching live stats
      _.each(this.site.get('categories'), function(c) {
        if (!c.get('read_restricted')) {
          topicCount += c.get('topic_count');
          postCount  += c.get('post_count');
        }
      });

      if (topicCount < this.get('requiredTopics') || postCount < this.get('requiredPosts')) {
        this.set('enabled', true);
        this.fetchLiveStats();
      }
    }
  },

  @computed()
  shouldSee() {
    return Discourse.User.currentProp('admin') && this.siteSettings.show_create_topics_notice;
  },

  @computed('enabled', 'shouldSee', 'publicTopicCount', 'publicPostCount')
  hidden() {
    return !this.get('enabled') || !this.get('shouldSee') || this.get('publicTopicCount') == null || this.get('publicPostCount') == null;
  },

  @computed('publicTopicCount', 'publicPostCount', 'topicTrackingState.incomingCount')
  message() {
    return new Handlebars.SafeString(I18n.t('too_few_topics_notice', {
      requiredTopics: this.get('requiredTopics'),
      requiredPosts:  this.get('requiredPosts'),
      currentTopics:  this.get('publicTopicCount'),
      currentPosts:   this.get('publicPostCount')
    }));
  },

  @computed()
  topicTrackingState() {
    return Discourse.TopicTrackingState.current();
  },

  @observes('topicTrackingState.incomingCount')
  fetchLiveStats() {
    if (!this.get('enabled')) { return; }

    var self = this;
    LivePostCounts.find().then(function(stats) {
      if(stats) {
        self.set('publicTopicCount', stats.get('public_topic_count'));
        self.set('publicPostCount', stats.get('public_post_count'));
        if (self.get('publicTopicCount') >= self.get('requiredTopics')
            && self.get('publicPostCount') >= self.get('requiredPosts')) {
          self.set('enabled', false); // No more checks
        }
      }
    });
  }
});
