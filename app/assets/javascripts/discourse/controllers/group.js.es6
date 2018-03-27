import { default as computed } from 'ember-addons/ember-computed-decorators';

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

  @computed('showMessages', 'model.user_count')
  tabs(showMessages, userCount) {
    const membersTab = Tab.create({
      name: 'members',
      route: 'group.index',
      icon: 'users',
      i18nKey: "members.title"
    });

    membersTab.set('count', userCount);

    const defaultTabs = [
      membersTab,
      Tab.create({ name: 'activity' })
    ];

    if (showMessages) {
      defaultTabs.push(Tab.create({
        name: 'messages', i18nKey: 'messages'
      }));
    }

    if (this.currentUser && this.currentUser.canManageGroup(this.model)) {
      defaultTabs.push(
        Tab.create({
          name: 'manage', i18nKey: 'manage.title', icon: 'wrench'
        })
      );
    }

    return defaultTabs;
  },

  @computed('model.is_group_user')
  showMessages(isGroupUser) {
    if (!this.siteSettings.enable_personal_messages) {
      return false;
    }

    return isGroupUser || (this.currentUser && this.currentUser.admin);
  },

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

  @computed('model')
  canManageGroup(model) {
    return this.currentUser && this.currentUser.canManageGroup(model);
  },

  actions: {
    messageGroup() {
      this.send('createNewMessageViaParams', this.get('model.name'));
    }
  }
});
