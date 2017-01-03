import { default as computed } from 'ember-addons/ember-computed-decorators';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Component.extend({
  @computed("model.public")
  canJoinGroup(publicGroup) {
    return publicGroup;
  },

  @computed('model.allow_membership_requests', 'model.alias_level')
  canRequestMembership(allowMembershipRequests, aliasLevel) {
    return allowMembershipRequests && aliasLevel === 99;
  },

  @computed("model.is_group_user", "model.id", "groupUserIds")
  userIsGroupUser(isGroupUser, groupId, groupUserIds) {
    if (isGroupUser) {
      return isGroupUser;
    } else {
      return !!groupUserIds && groupUserIds.includes(groupId);
    }
  },

  @computed
  joinGroupAction() {
    return this.currentUser ? 'joinGroup' : 'showLogin';
  },

  @computed
  requestMembershipAction() {
    return this.currentUser ? 'requestMembership' : 'showLogin';
  },

  actions: {
    showLogin() {
      this.sendAction('showLogin');
    },

    joinGroup() {
      this.set('updatingMembership', true);
      const model = this.get('model');

      if (!!(this.currentUser)) {

      }

      model.addMembers(this.currentUser.get('username')).then(() => {
        model.set('is_group_user', true);
      }).catch(popupAjaxError).finally(() => {
        this.set('updatingMembership', false);
      });
    },

    leaveGroup() {
      this.set('updatingMembership', true);
      const model = this.get('model');

      model.removeMember(this.currentUser).then(() => {
        model.set('is_group_user', false);
      }).catch(popupAjaxError).finally(() => {
        this.set('updatingMembership', false);
      });
    },

    requestMembership() {
      const groupName = this.get('model.name');
      const title = I18n.t('groups.request_membership_pm.title');
      const body = I18n.t('groups.request_membership_pm.body', { groupName });
      this.sendAction("createNewMessageViaParams", groupName, title, body);
    }
  }
});
