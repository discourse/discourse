import FlaggedPost from 'admin/models/flagged-post';
import showModal from 'discourse/lib/show-modal';

export default Ember.Component.extend({
  canAct: Ember.computed.equal('filter', 'active'),
  showResolvedBy: Ember.computed.equal('filter', 'old'),

  removeAfter(promise, flaggedPost) {
    return promise.then(() => {
      this.get('flaggedPosts').removeObject(flaggedPost);
    }).catch(() => {
      bootbox.alert(I18n.t("admin.flags.error"));
    });
  },

  _spawnModal(name, flaggedPost, modalClass) {
    let controller = showModal(name, {
      model: flaggedPost,
      admin: true,
      modalClass
    });
    controller.removeAfter = (p, f) => this.removeAfter(p, f);
  },

  actions: {
    disagree(flaggedPost) {
      this.removeAfter(flaggedPost.disagreeFlags(), flaggedPost);
    },

    defer(flaggedPost) {
      this.removeAfter(flaggedPost.deferFlags(), flaggedPost);
    },

    loadMore() {
      const flaggedPosts = this.get('flaggedPosts');
      return FlaggedPost.findAll(this.get('query'), flaggedPosts.length+1).then(data => {
        if (data.length===0) {
          flaggedPosts.set("allLoaded",true);
        }
        flaggedPosts.addObjects(data);
      });
    },

    showAgreeFlagModal(flaggedPost) {
      this._spawnModal('admin-agree-flag', flaggedPost, 'agree-flag-modal');
    },

    showDeleteFlagModal(flaggedPost) {
      this._spawnModal('admin-delete-flag', flaggedPost, 'delete-flag-modal');
    }
  }
});
