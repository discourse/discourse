import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

var Tab = Em.Object.extend({
  @computed('name')
  location(name) {
    return 'group.' + name;
  },

  @computed('name')
  message(name) {
    return I18n.t('groups.' + name);
  }
});


export default Ember.Controller.extend({
  counts: null,
  showing: 'posts',

  @observes('counts')
  countsChanged() {
    const counts = this.get('counts');
    this.get('tabs').forEach(tab => {
      tab.set('count', counts.get(tab.get('name')));
    });
  },

  @observes('showing')
  showingChanged() {
    const showing = this.get('showing');

    this.get('tabs').forEach(tab => {
      tab.set('active', showing === tab.get('name'));
    });
  },

  tabs: [
    Tab.create({ name: 'posts', active: true, 'location': 'group.index' }),
    Tab.create({ name: 'topics' }),
    Tab.create({ name: 'mentions' }),
    Tab.create({ name: 'members' }),
    Tab.create({ name: 'messages' }),
  ]
});
