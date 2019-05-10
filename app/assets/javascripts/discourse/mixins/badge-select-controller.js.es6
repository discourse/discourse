import Badge from "discourse/models/badge";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Mixin.create({
  saving: false,
  saved: false,

  @computed("filteredList")
  selectableUserBadges(items) {
    items = _.uniq(items, false, function(e) {
      return e.get("badge.name");
    });
    items.unshiftObject(
      Ember.Object.create({
        badge: Badge.create({ name: I18n.t("badges.none") })
      })
    );
    return items;
  },

  @computed("saving")
  savingStatus(saving) {
    return saving ? I18n.t("saving") : I18n.t("save");
  },

  @computed("selectedUserBadgeId")
  selectedUserBadge(selectedUserBadgeId) {
    selectedUserBadgeId = parseInt(selectedUserBadgeId);
    let selectedUserBadge = null;
    this.get("selectableUserBadges").forEach(function(userBadge) {
      if (userBadge.get("id") === selectedUserBadgeId) {
        selectedUserBadge = userBadge;
      }
    });
    return selectedUserBadge;
  },

  disableSave: Ember.computed.alias("saving")
});
