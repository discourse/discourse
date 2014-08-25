Discourse.AdminBadgesRoute = Discourse.Route.extend({
  setupController: function(controller) {
    Discourse.ajax('/admin/badges.json').then(function(json){

      controller.set('badgeGroupings', Em.A(json.badge_groupings));
      controller.set('badgeTypes', json.badge_types);
      controller.set('protectedSystemFields', json.admin_badges.protected_system_fields);
      var triggers = [];
      _.each(json.admin_badges.triggers,function(v,k){
        triggers.push({id: v, name: I18n.t('admin.badges.trigger_type.'+k)});
      });
      controller.set('badgeTriggers', triggers);
      controller.set('model', Discourse.Badge.createFromJson(json));
    });
  },

  actions: {
    editGroupings: function(model) {
      Discourse.Route.showModal(this, 'admin_edit_badge_groupings', model);
    },

    saveError: function(jqXhr) {
      if (jqXhr.status === 422) {
        Discourse.Route.showModal(this, 'admin_badge_preview', jqXhr.responseJSON);
      } else {
        Em.Logger.error(jqXhr);
        bootbox.alert(I18n.t('errors.description.unknown'));
      }
    },

    preview: function(badge, explain) {
      var self = this;

      badge.set('preview_loading', true);
      Discourse.ajax('/admin/badges/preview.json', {
        method: 'post',
        data: {
          sql: badge.query,
          target_posts: !!badge.target_posts,
          trigger: badge.trigger,
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
