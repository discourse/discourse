/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { isEmpty } from "@ember/utils";
import { observes, on } from "@ember-decorators/object";
import $ from "jquery";
import groupAutocomplete from "discourse/lib/autocomplete/group";
import discourseComputed from "discourse/lib/decorators";
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

        if (this.onChange) {
          this.onChange(items.join(","));
        } else if (this.onChangeCallback) {
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
      template: groupAutocomplete,
    });
  }

  <template>
    <input
      placeholder={{this.placeholder}}
      class="group-selector"
      type="text"
      name="groups"
    />
  </template>
}
