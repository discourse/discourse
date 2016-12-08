import { ajax } from 'discourse/lib/ajax';
import BadgeSelectController from "discourse/mixins/badge-select-controller";

export default Ember.Controller.extend(BadgeSelectController, {
  filteredList: function() {
    return this.get('model').filter(function(b) {
      return !Ember.isEmpty(b.get('badge.image'));
    });
  }.property('model'),

  actions: {
    save: function() {
      this.setProperties({ saved: false, saving: true });

      ajax(this.get('user.path') + "/preferences/card-badge", {
        type: "PUT",
        data: { user_badge_id: this.get('selectedUserBadgeId') }
      }).then(() => {
        this.setProperties({
          saved: true,
          saving: false,
          "user.card_image_badge": this.get('selectedUserBadge.badge.image')
        });
      }).catch(() => {
        this.set('saving', false);
        bootbox.alert(I18n.t('generic_error'));
      });
    }
  }
});
