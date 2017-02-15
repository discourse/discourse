import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

var Tab = Em.Object.extend({
  @computed('name')
  location(name) {
    return 'group.' + name;
  },

  @computed('name', 'i18nKey')
  message(name, i18nKey) {
    return I18n.t(`groups.${i18nKey || name}`);
  }
});

export default Ember.Controller.extend({
  application: Ember.inject.controller(),
  counts: null,
  showing: 'members',

  tabs: [
    Tab.create({ name: 'members', 'location': 'group.index', icon: 'users' }),
    Tab.create({ name: 'activity' }),
    Tab.create({
      name: 'edit', i18nKey: 'edit.title', icon: 'pencil', requiresGroupAdmin: true
    }),
    Tab.create({
      name: 'logs', i18nKey: 'logs.title', icon: 'list-alt', requiresGroupAdmin: true
    })
  ],

  @computed('model.is_group_owner', 'model.automatic')
  canEditGroup(isGroupOwner, automatic) {
    return !automatic && isGroupOwner;
  },

  @computed('model.name', 'model.full_name')
  groupName(name, fullName) {
    return (fullName || name).capitalize();
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

  @computed('model.is_group_user', 'model.is_group_owner', 'model.automatic')
  getTabs(isGroupUser, isGroupOwner, automatic) {
    return this.get('tabs').filter(t => {
      let display = true;

      if (this.currentUser && t.get('requiresGroupAdmin')) {
        display = automatic ? false : (this.currentUser.admin || isGroupOwner);
      } else if (t.get('requiresGroupAdmin')) {
        display = false;
      }

      return display;
    });
  }
});
