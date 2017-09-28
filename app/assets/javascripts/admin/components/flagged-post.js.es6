import showModal from 'discourse/lib/show-modal';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  adminTools: Ember.inject.service(),
  expanded: false,
  suspended: false,

  tagName: 'div',
  classNameBindings: [
    ':flagged-post',
    'flaggedPost.hidden:hidden-post',
    'flaggedPost.deleted'
  ],

  @computed('filter')
  canAct(filter) {
    return filter === 'active';
  },

  removeAfter(promise) {
    return promise.then(() => {
      this.attrs.removePost();
    }).catch(() => {
      bootbox.alert(I18n.t("admin.flags.error"));
    });
  },

  _spawnModal(name, model, modalClass) {
    let controller = showModal(name, { model, admin: true, modalClass });
    controller.removeAfter = (p) => this.removeAfter(p);
  },

  actions: {
    showAgreeFlagModal() {
      this._spawnModal('admin-agree-flag', this.get('flaggedPost'), 'agree-flag-modal');
    },

    showDeleteFlagModal() {
      this._spawnModal('admin-delete-flag', this.get('flaggedPost'), 'delete-flag-modal');
    },

    disagree() {
      this.removeAfter(this.get('flaggedPost').disagreeFlags());
    },

    defer() {
      this.removeAfter(this.get('flaggedPost').deferFlags());
    },

    expand() {
      this.get('flaggedPost').expandHidden().then(() => {
        this.set('expanded', true);
      });
    },

    showSuspendModal() {
      let post = this.get('flaggedPost');
      let user = post.get('user');
      this.get('adminTools').showSuspendModal(
        user,
        {
          post,
          successCallback: result => this.set('suspended', result.suspended)
        }
      );
    }
  }
});
