import Badge from 'discourse/models/badge';
import showModal from 'discourse/lib/show-modal';

export default Ember.Route.extend({
  serialize(m) {
    return {badge_id: Em.get(m, 'id') || 'new'};
  },

  model(params) {
    if (params.badge_id === "new") {
      return Badge.create({
        name: I18n.t('admin.badges.new_badge')
      });
    }
    return this.modelFor('adminBadges').findProperty('id', parseInt(params.badge_id));
  },

  actions: {
    saveError(e) {
      let msg = I18n.t("generic_error");
      if (e.responseJSON && e.responseJSON.errors) {
        msg = I18n.t("generic_error_with_reason", {error: e.responseJSON.errors.join('. ')});
      }
      bootbox.alert(msg);
    },

    editGroupings() {
      const model = this.controllerFor('admin-badges').get('badgeGroupings');
      showModal('modals/admin-edit-badge-groupings', { model });
    },

    preview(badge, explain) {
      badge.set('preview_loading', true);
      Discourse.ajax('/admin/badges/preview.json', {
        method: 'post',
        data: {
          sql: badge.get('query'),
          target_posts: !!badge.get('target_posts'),
          trigger: badge.get('trigger'),
          explain
        }
      }).then(function(model) {
        badge.set('preview_loading', false);
        showModal('modals/admin-badge-preview', { model });
      }).catch(function(error) {
        badge.set('preview_loading', false);
        Em.Logger.error(error);
        bootbox.alert("Network error");
      });
    }
  }

});
