import { default as computed } from 'ember-addons/ember-computed-decorators';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import Group from 'discourse/models/group';

export default Ember.Component.extend({
  @computed("model.public")
  canJoinGroup(publicGroup) {
    return publicGroup;
  },

  @computed("model.is_group_user", "model.id", "groupUserIds")
  userIsGroupUser(isGroupUser, groupId, groupUserIds) {
    if (isGroupUser !== undefined) {
      return isGroupUser;
    } else {
      return !!groupUserIds && groupUserIds.includes(groupId);
    }
  },

  @computed
  disableRequestMembership() {
    if (this.currentUser) {
      return this.currentUser.trust_level < this.siteSettings.min_trust_to_send_messages;
    } else {
      return false;
    }
  },

  @computed("disableRequestMembership")
  requestMembershipButtonTitle(disableRequestMembership) {
    if (disableRequestMembership) {
      return "groups.request_membership_pm.disabled";
    }
  },

  _showLoginModal() {
    this.sendAction('showLogin');
    $.cookie('destination_url', window.location.href);
  },

  actions: {
    joinGroup() {
      if (this.currentUser) {
        this.set('updatingMembership', true);
        const model = this.get('model');

        model.addMembers(this.currentUser.get('username')).then(() => {
          model.set('is_group_user', true);
        }).catch(popupAjaxError).finally(() => {
          this.set('updatingMembership', false);
        });
      } else {
        this._showLoginModal();
      }
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
      if (this.currentUser) {
        const groupName = this.get('model.name');

        Group.loadOwners(groupName).then(result => {
          const names = result.map(owner => owner.username).join(",");
          const title = I18n.t('groups.request_membership_pm.title');
          const body = I18n.t('groups.request_membership_pm.body', { groupName });
          this.sendAction("createNewMessageViaParams", names, title, body);
        });
      } else {
        this._showLoginModal();
      }
    }
  }
});
