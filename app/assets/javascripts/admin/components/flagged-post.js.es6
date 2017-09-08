import showModal from 'discourse/lib/show-modal';

export default Ember.Component.extend({
  tagName: '',

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
    }
  }
});
