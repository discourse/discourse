import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({

  @computed('topic.isPrivateMessage')

});
