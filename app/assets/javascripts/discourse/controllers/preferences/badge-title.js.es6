import { ajax } from 'discourse/lib/ajax';
import BadgeSelectController from "discourse/mixins/badge-select-controller";

export default Ember.Controller.extend(BadgeSelectController, {

  filteredList: function() {
    return this.get('model').filterBy('badge.allow_title', true);
  }.property('model'),

  actions: {
    save() {
      this.setProperties({ saved: false, saving: true });

      ajax(this.get('user.path') + "/preferences/badge_title", {
        type: "PUT",
        data: { user_badge_id: this.get('selectedUserBadgeId') }
      }).then(() => {
        this.setProperties({
          saved: true,
          saving: false,
          "user.title": this.get('selectedUserBadge.badge.name')
        });
      }, () => {
        bootbox.alert(I18n.t('generic_error'));
      });
    }
  }
});
