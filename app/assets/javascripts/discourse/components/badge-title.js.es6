import { ajax } from "discourse/lib/ajax";
import BadgeSelectController from "discourse/mixins/badge-select-controller";

export default Ember.Component.extend(BadgeSelectController, {
  classNames: ["badge-title"],

  saved: false,
  saving: false,

  actions: {
    save() {
      this.setProperties({ saved: false, saving: true });

      const badge_id = this.get("selectedUserBadgeId") || 0;

      ajax(this.get("user.path") + "/preferences/badge_title", {
        type: "PUT",
        data: { user_badge_id: badge_id }
      }).then(
        () => {
          this.setProperties({
            saved: true,
            saving: false,
            "user.title": this.get("selectedUserBadge.badge.name")
          });
        },
        () => {
          bootbox.alert(I18n.t("generic_error"));
        }
      );
    }
  }
});
