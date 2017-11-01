import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

const Tab = Ember.Object.extend({
  init() {
    this._super();
    let name = this.get('name');
    this.set('route', this.get('route') || `group.` + name);
    this.set('message', I18n.t(`groups.${this.get('i18nKey') || name}`));
  }
});

export default Ember.Controller.extend({
  application: Ember.inject.controller(),
  counts: null,
  showing: 'members',

  tabs: [
    Tab.create({ name: 'members', route: 'group.index', icon: 'users' }),
    Tab.create({ name: 'activity' }),
    Tab.create({
      name: 'edit', i18nKey: 'edit.title', icon: 'pencil', admin: true
    }),
    Tab.create({
      name: 'logs', i18nKey: 'logs.title', icon: 'list-alt', admin: true
    })
  ],

  @computed('model.is_group_owner', 'model.automatic')
  canEditGroup(isGroupOwner, automatic) {
    return !automatic && isGroupOwner;
  },

  @computed('model.displayName', 'model.full_name')
  groupName(displayName, fullName) {
    return (fullName || displayName).capitalize();
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

  @computed("model.messageable")
  displayGroupMessageButton(messageable) {
    return this.currentUser && messageable;
  },

  @observes('model.user_count')
  _setMembersTabCount() {
    this.get('tabs')[0].set('count', this.get('model.user_count'));
  },

  actions: {
    messageGroup() {
      this.send('createNewMessageViaParams', this.get('model.name'));
    }
  }
});
