export default Ember.Route.extend({
  serialize: function(m) {
    return {badge_id: Em.get(m, 'id') || 'new'};
  },

  model: function(params) {
    if (params.badge_id === "new") {
      return Discourse.Badge.create({
        name: I18n.t('admin.badges.new_badge')
      });
    }
    return this.modelFor('adminBadges').findProperty('id', parseInt(params.badge_id));
  },

  actions: {
    saveError: function(e) {
      var msg = I18n.t("generic_error");
      if (e.responseJSON && e.responseJSON.errors) {
        msg = I18n.t("generic_error_with_reason", {error: e.responseJSON.errors.join('. ')});
      }
      bootbox.alert(msg);
    },

    editGroupings: function() {
      var groupings = this.controllerFor('admin-badges').get('badgeGroupings');
      Discourse.Route.showModal(this, 'admin_edit_badge_groupings', groupings);
    },

    preview: function(badge, explain) {
      var self = this;

      badge.set('preview_loading', true);
      Discourse.ajax('/admin/badges/preview.json', {
        method: 'post',
        data: {
          sql: badge.get('query'),
          target_posts: !!badge.get('target_posts'),
          trigger: badge.get('trigger'),
          explain: explain
        }
      }).then(function(json) {
        badge.set('preview_loading', false);
        Discourse.Route.showModal(self, 'admin_badge_preview', json);
      }).catch(function(error) {
        badge.set('preview_loading', false);
        Em.Logger.error(error);
        bootbox.alert("Network error");
      });
    }
  }

});
