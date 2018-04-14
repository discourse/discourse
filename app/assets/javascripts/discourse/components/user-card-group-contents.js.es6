import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  group: null,

  showMoreMembers: Ember.computed.gt('moreMembersCount', 0),

  @computed('group.user_count', 'group.members.length')
  moreMembersCount: (memberCount, maxMemberDisplay) => memberCount - maxMemberDisplay,

  @computed('group')
  groupPath(group) {
    return `${Discourse.BaseUri}/groups/${group.name}`;
  },

  actions: {
    close() {
      this.sendAction('close');
    },

    messageGroup() {
      this.sendAction('messageGroup');
    },

    showGroup() {
      this.sendAction('showGroup');
    },
    showUser(user) {
      this.sendAction('showUser', user);
    },
  }
});
