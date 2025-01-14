import Component from "@ember/component";
import { isEmpty } from "@ember/utils";
import { observes, on } from "@ember-decorators/object";
import $ from "jquery";
import discourseComputed from "discourse/lib/decorators";
import { findRawTemplate } from "discourse/lib/raw-templates";
import { i18n } from "discourse-i18n";

export default class GroupSelector extends Component {
  @discourseComputed("placeholderKey")
  placeholder(placeholderKey) {
    return placeholderKey ? i18n(placeholderKey) : "";
  }

  @observes("groupNames")
  _update() {
    if (this.canReceiveUpdates === "true") {
      this._initializeAutocomplete({ updateData: true });
    }
  }

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
  }
}
