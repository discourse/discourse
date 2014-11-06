import BadgeSelectController from "discourse/mixins/badge-select-controller";

export default Ember.ArrayController.extend(BadgeSelectController, {
  filteredList: function() {
    return this.get('model').filter(function(b) {
      return !Em.empty(b.get('badge.image'));
    });
  }.property('model'),

  actions: {
    save: function() {
      this.setProperties({ saved: false, saving: true });

      var self = this;
      Discourse.ajax(this.get('user.path') + "/preferences/card-badge", {
        type: "PUT",
        data: { user_badge_id: self.get('selectedUserBadgeId') }
      }).then(function() {
        self.setProperties({
          saved: true,
          saving: false,
          "user.card_image_badge": self.get('selectedUserBadge.badge.image')
        });
      }).catch(function() {
        self.set('saving', false);
        bootbox.alert(I18n.t('generic_error'));
      });
    }
  }
});
