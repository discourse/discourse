import { ajax } from 'discourse/lib/ajax';
import BadgeSelectController from "discourse/mixins/badge-select-controller";

export default Ember.ArrayController.extend(BadgeSelectController, {

  filteredList: function() {
    return this.get('model').filterBy('badge.allow_title', true);
  }.property('model'),

  actions: {
    save: function() {
      this.setProperties({ saved: false, saving: true });

      var self = this;
      ajax(this.get('user.path') + "/preferences/badge_title", {
        type: "PUT",
        data: { user_badge_id: self.get('selectedUserBadgeId') }
      }).then(function() {
        self.setProperties({
          saved: true,
          saving: false,
          "user.title": self.get('selectedUserBadge.badge.name')
        });
      }, function() {
        bootbox.alert(I18n.t('generic_error'));
      });
    }
  }
});
