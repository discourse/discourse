import { default as computed } from 'ember-addons/ember-computed-decorators';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import DiscourseURL from 'discourse/lib/url';

export default Ember.Component.extend({
  loading: false,

  @computed("model.public_admission", "userIsGroupUser")
  canJoinGroup(publicAdmission, userIsGroupUser) {
    return publicAdmission && !userIsGroupUser;
  },

  @computed("model.public_exit", "userIsGroupUser")
  canLeaveGroup(publicExit, userIsGroupUser) {
    return publicExit && userIsGroupUser;
  },

  @computed("model.is_group_user", "model.id", "groupUserIds")
  userIsGroupUser(isGroupUser, groupId, groupUserIds) {
    if (isGroupUser !== undefined) {
      return isGroupUser;
    } else {
      return !!groupUserIds && groupUserIds.includes(groupId);
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
        this.set('loading', true);

        this.get('model').requestMembership().then(result => {
          DiscourseURL.routeTo(result.relative_url);
        }).catch(popupAjaxError).finally(() => {
          this.set('loading', false);
        });
      } else {
        this._showLoginModal();
      }
    }
  }
});
