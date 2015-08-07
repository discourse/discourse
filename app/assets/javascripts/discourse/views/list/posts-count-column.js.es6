import { fmt } from 'discourse/lib/computed';

export default Ember.Object.extend({
  tagName: "td",
  ratio: function() {
    var likes = parseFloat(this.get('topic.like_count')),
        posts = parseFloat(this.get('topic.posts_count'));

    if (posts < 10) { return 0; }

    return (likes || 0) / posts;
  }.property(),

  title: function() {
    return I18n.messageFormat('posts_likes_MF', {
      count: this.get('topic.replyCount'),
      ratio: this.get('ratioText')
    }).trim();
  }.property(),

  ratioText: function() {
    var ratio = this.get('ratio');

    var settings = Discourse.SiteSettings;
    if (ratio > settings.topic_post_like_heat_high) { return 'high'; }
    if (ratio > settings.topic_post_like_heat_medium) { return 'med'; }
    if (ratio > settings.topic_post_like_heat_low) { return 'low'; }
    return '';
  }.property(),

  likesHeat: fmt('ratioText', 'heatmap-%@'),
});

