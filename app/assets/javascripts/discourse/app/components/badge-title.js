import Component from "@ember/component";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";

export default Component.extend({
  classNames: ["badge-title"],

  selectedUserBadgeId: null,
  selectableUserBadges: null,
  saved: false,
  saving: false,

  init() {
    this._super(...arguments);

    const badge = this.selectableUserBadges.findBy(
      "badge.name",
      this.currentUser.title
    );
    this.selectedUserBadgeId = badge ? badge.id : 0;
  },

  actions: {
    save() {
      this.setProperties({ saved: false, saving: true });

      const selectedUserBadge = this.selectableUserBadges.findBy(
        "id",
        this.selectedUserBadgeId
      );

      ajax(this.currentUser.path + "/preferences/badge_title", {
        type: "PUT",
        data: { user_badge_id: selectedUserBadge ? selectedUserBadge.id : 0 },
      }).then(
        () => {
          this.setProperties({
            saved: true,
            saving: false,
          });
          this.currentUser.set(
            "title",
            selectedUserBadge ? selectedUserBadge.badge.name : ""
          );
        },
        () => {
          bootbox.alert(I18n.t("generic_error"));
        }
      );
    },
  },
});
