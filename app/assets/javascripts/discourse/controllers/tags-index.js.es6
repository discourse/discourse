import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  sortProperties: ['count:desc', 'id'],

  canAdminTags: Ember.computed.alias("currentUser.staff"),
  groupedByCategory: Ember.computed.notEmpty('model.extras.categories'),
  groupedByTagGroup: Ember.computed.notEmpty('model.extras.tag_groups'),

  @computed('groupedByCategory', 'groupedByTagGroup')
  otherTagsTitleKey(groupedByCategory, groupedByTagGroup) {
    if (!groupedByCategory && !groupedByTagGroup) {
      return 'tagging.all_tags';
    } else {
      return 'tagging.other_tags';
    }
  },

  actions: {
    sortByCount() {
      this.set('sortProperties', ['count:desc', 'id']);
    },

    sortById() {
      this.set('sortProperties', ['id']);
    }
  }
});
