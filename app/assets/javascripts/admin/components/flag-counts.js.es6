import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: ['flag-counts'],

  @computed('details.flag_type_id')
  title(id) {
    return I18n.t(`admin.flags.summary.action_type_${id}`, { count: 1 });
  }
});
