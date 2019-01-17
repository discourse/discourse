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

  @observes("groupNames")
  _update() {
    if (this.get("canReceiveUpdates") === "true")
      this._initializeAutocomplete({ updateData: true });
  },

  @on("didInsertElement")
  _initializeAutocomplete(opts) {
    let selectedGroups;
    let groupNames = this.get("groupNames");

    this.$("input").autocomplete({
      allowAny: false,
      items: _.isArray(groupNames)
        ? groupNames
        : Ember.isEmpty(groupNames)
        ? []
        : [groupNames],
      single: this.get("single"),
      updateData: opts && opts.updateData ? opts.updateData : false,
      onChangeItems: items => {
        selectedGroups = items;
        this.set("groupNames", items.join(","));
      },
      transformComplete: g => {
        return g.name;
      },
      dataSource: term => {
        return this.get("groupFinder")(term).then(groups => {
          if (!selectedGroups) return groups;

          return groups.filter(group => {
            return !selectedGroups.any(s => s === group.name);
          });
        });
      },
      template: findRawTemplate("group-selector-autocomplete")
    });
  }
});
