import {
  on,
  observes,
  default as computed
} from "ember-addons/ember-computed-decorators";
import { findRawTemplate } from "discourse/lib/raw-templates";

export default Ember.Component.extend({
  @computed("placeholderKey")
  placeholder(placeholderKey) {
    return placeholderKey ? I18n.t(placeholderKey) : "";
  },

  @observes("badgeNames")
  _update() {
    if (this.get("canReceiveUpdates") === "true")
      this._initializeAutocomplete({ updateData: true });
  },

  @on("didInsertElement")
  _initializeAutocomplete(opts) {
    var self = this;
    var selectedBadges;

    self.$("input").autocomplete({
      allowAny: false,
      items: _.isArray(this.get("badgeNames"))
        ? this.get("badgeNames")
        : [this.get("badgeNames")],
      single: this.get("single"),
      updateData: opts && opts.updateData ? opts.updateData : false,
      onChangeItems: function(items) {
        selectedBadges = items;
        self.set("badgeNames", items.join(","));
      },
      transformComplete: function(g) {
        return g.name;
      },
      dataSource: function(term) {
        return self
          .get("badgeFinder")(term)
          .then(function(badges) {
            if (!selectedBadges) {
              return badges;
            }

            return badges.filter(function(badge) {
              return !selectedBadges.any(function(s) {
                return s === badge.name;
              });
            });
          });
      },
      template: findRawTemplate("badge-selector-autocomplete")
    });
  }
});
