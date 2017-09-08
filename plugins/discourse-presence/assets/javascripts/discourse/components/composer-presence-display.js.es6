import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  composer: Ember.inject.controller(),

  @computed('composer.presenceUsers', 'currentUser.id')
  users(presenceUsers, currentUser_id){
    return presenceUsers.filter(user => user.id !== currentUser_id);
  },

  @computed('composer.presenceState.action')
  isReply(action){
    return action === 'reply';
  },

  @computed('users.length')
  shouldDisplay(length){
    return length > 0;
  }

});
