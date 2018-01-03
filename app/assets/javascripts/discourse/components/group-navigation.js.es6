import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  tagName: '',

  @computed('group')
  availableTabs(group) {
    return this.get('tabs').filter(t => {
      if (t.admin) {
        return this.currentUser ? this.currentUser.canManageGroup(group) : false;
      }
      return true;
    });
  }
});
