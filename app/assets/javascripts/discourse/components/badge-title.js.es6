import { ajax } from "discourse/lib/ajax";
import BadgeSelectController from "discourse/mixins/badge-select-controller";

export default Ember.Component.extend(BadgeSelectController, {
  classNames: ["badge-title"],

  saved: false,
  saving: false,

  actions: {
    save() {
      this.setProperties({ saved: false, saving: true });

      const badge_id = this.selectedUserBadgeId || 0;

      ajax(this.currentUser.path + "/preferences/badge_title", {
        type: "PUT",
        data: { user_badge_id: badge_id }
      }).then(
        () => {
          this.setProperties({
            saved: true,
            saving: false
          });
          this.currentUser.set(
            "title",
            this.get("selectedUserBadge.badge.name")
          );
        },
        () => {
          bootbox.alert(I18n.t("generic_error"));
        }
      );
    }
  }
});
