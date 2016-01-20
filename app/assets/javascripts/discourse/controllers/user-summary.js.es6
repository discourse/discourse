export default Ember.Controller.extend({
  needs: ['user'],
  user: Em.computed.alias('controllers.user.model'),
  moreTopics: function(){
    return this.get('model.topics').length > 5;
  }.property('model'),
  moreReplies: function(){
    return this.get('model.replies').length > 5;
  }.property('model'),
  moreBadges: function(){
    return this.get('model.badges').length > 5;
  }.property('model')
});
