import discourseComputed, {
  observes,
  on,
} from "discourse-common/utils/decorators";
import Component from "@ember/component";
import I18n from "I18n";
import { findRawTemplate } from "discourse-common/lib/raw-templates";
import { isEmpty } from "@ember/utils";

export default Component.extend({
  @discourseComputed("placeholderKey")
  placeholder(placeholderKey) {
    return placeholderKey ? I18n.t(placeholderKey) : "";
  },

  @observes("groupNames")
  _update() {
    if (this.canReceiveUpdates === "true") {
      this._initializeAutocomplete({ updateData: true });
    }
  },

  @on("didInsertElement")
  _initializeAutocomplete(opts) {
    let selectedGroups;
    let groupNames = this.groupNames;

    $(this.element.querySelector("input")).autocomplete({
      debounced: true,
      allowAny: false,
      items: Array.isArray(groupNames)
        ? groupNames
        : isEmpty(groupNames)
        ? []
        : [groupNames],
      single: this.single,
      fullWidthWrap: this.fullWidthWrap,
      updateData: opts && opts.updateData ? opts.updateData : false,
      onChangeItems: (items) => {
        selectedGroups = items;

        if (this.onChangeCallback) {
          this.onChangeCallback(this.groupNames, selectedGroups);
        } else {
          this.set("groupNames", items.join(","));
        }
      },
      transformComplete: (g) => {
        return g.name;
      },
      dataSource: (term) => {
        return this.groupFinder(term).then((groups) => {
          if (!selectedGroups) {
            return groups;
          }

          return groups.filter((group) => {
            return !selectedGroups.any((s) => s === group.name);
          });
        });
      },
      template: findRawTemplate("group-selector-autocomplete"),
    });
  },
});
