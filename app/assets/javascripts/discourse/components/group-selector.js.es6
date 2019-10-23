import Component from "@ember/component";
import {
  on,
  observes,
  default as computed
} from "ember-addons/ember-computed-decorators";
import { findRawTemplate } from "discourse/lib/raw-templates";

export default Component.extend({
  @computed("placeholderKey")
  placeholder(placeholderKey) {
    return placeholderKey ? I18n.t(placeholderKey) : "";
  },

  @observes("groupNames")
  _update() {
    if (this.canReceiveUpdates === "true")
      this._initializeAutocomplete({ updateData: true });
  },

  @on("didInsertElement")
  _initializeAutocomplete(opts) {
    let selectedGroups;
    let groupNames = this.groupNames;

    $(this.element.querySelector("input")).autocomplete({
      allowAny: false,
      items: _.isArray(groupNames)
        ? groupNames
        : Ember.isEmpty(groupNames)
        ? []
        : [groupNames],
      single: this.single,
      fullWidthWrap: this.fullWidthWrap,
      updateData: opts && opts.updateData ? opts.updateData : false,
      onChangeItems: items => {
        selectedGroups = items;
        this.set("groupNames", items.join(","));
      },
      transformComplete: g => {
        return g.name;
      },
      dataSource: term => {
        return this.groupFinder(term).then(groups => {
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
