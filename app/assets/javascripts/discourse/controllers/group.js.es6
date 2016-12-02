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
  showing: 'members',
  tabs: [
    Tab.create({ name: 'members', active: true, 'location': 'group.index' }),
    Tab.create({ name: 'posts' }),
    Tab.create({ name: 'topics' }),
    Tab.create({ name: 'mentions' }),
    Tab.create({ name: 'messages', requiresMembership: true })
  ],

  @computed('model.name')
  groupName(name) {
    return name.capitalize();
  },

  @computed('model.name', 'model.flair_url', 'model.flair_bg_color', 'model.flair_color')
  avatarFlairAttributes(groupName, flairURL, flairBgColor, flairColor) {
    return {
      primary_group_flair_url: flairURL,
      primary_group_flair_bg_color: flairBgColor,
      primary_group_flair_color: flairColor,
      primary_group_name: groupName
    };
  },

  @observes('model.user_count')
  _setMembersTabCount() {
    this.get('tabs')[0].set('count', this.get('model.user_count'));
  },

  @observes('showing')
  showingChanged() {
    const showing = this.get('showing');

    this.get('tabs').forEach(tab => {
      tab.set('active', showing === tab.get('name'));
    });
  },

  @computed('model.is_group_user')
  getTabs(isGroupUser) {
    return this.get('tabs').filter(t => {
      let isMember = false;

      if (this.currentUser) {
        isMember = this.currentUser.admin || isGroupUser;
      }

      return isMember || !t.get('requiresMembership');
    });
  }
});
