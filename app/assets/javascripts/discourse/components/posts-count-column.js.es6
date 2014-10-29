export default Ember.Component.extend({
  tagName: 'td',
  classNameBindings: [':posts', 'likesHeat'],
  attributeBindings: ['title'],

  ratio: function() {
    var likes = parseFloat(this.get('topic.like_count')),
        posts = parseFloat(this.get('topic.posts_count'));

    if (posts < 10) { return 0; }

    return (likes || 0) / posts;
  }.property('topic.like_count', 'topic.posts_count'),

  title: function() {
    return I18n.messageFormat('posts_likes_MF', {
      count: this.get('topic.posts_count'),
      ratio: this.get('ratioText')
    }).trim();
  }.property('topic.posts_count', 'likesHeat'),

  ratioText: function() {
    var ratio = this.get('ratio');

    if (ratio > Discourse.SiteSettings.topic_post_like_heat_high) { return 'high'; }
    if (ratio > Discourse.SiteSettings.topic_post_like_heat_medium) { return 'med'; }
    if (ratio > Discourse.SiteSettings.topic_post_like_heat_low) { return 'low'; }
    return '';
  }.property('ratio'),

  likesHeat: Discourse.computed.fmt('ratioText', 'heatmap-%@'),

  render: function(buffer) {
    var postsCount = this.get('topic.posts_count');

    buffer.push("<a href class='badge-posts " + this.get('likesHeat') + "'>");
    buffer.push(Discourse.Formatter.number(postsCount));
    buffer.push("</a>");
  },

  click: function() {
    var topic = this.get('topic');

    this.sendAction('action', {
      topic: topic,
      position: this.$('a').offset()
    });

    return false;
  }

});
