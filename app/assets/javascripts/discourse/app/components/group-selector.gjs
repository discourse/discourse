import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import DMultiSelect from "discourse/components/d-multi-select";
import { i18n } from "discourse-i18n";

export default class GroupSelector extends Component {
  @service siteSettings;

  @tracked selectedGroups = [];

  constructor() {
    super(...arguments);
    this.initializeSelectedGroups();
  }

  initializeSelectedGroups() {
    const groupNames = this.args.groupNames;
    if (isEmpty(groupNames)) {
      this.selectedGroups = [];
      return;
    }

    // Convert groupNames (string or array) to array of group objects
    let names = Array.isArray(groupNames) ? groupNames : [groupNames];
    if (typeof groupNames === "string" && groupNames.includes(",")) {
      names = groupNames.split(",").map((name) => name.trim());
    }

    // Create minimal group objects from names
    this.selectedGroups = names
      .filter((name) => name && name.length > 0)
      .map((name) => ({ id: name, name }));
  }

  get placeholder() {
    return this.args.placeholderKey ? i18n(this.args.placeholderKey) : "";
  }

  get loadFn() {
    return async (term) => {
      if (!this.args.groupFinder) {
        return [];
      }

      return this.args.groupFinder(term);
    };
  }

  @action
  handleSelectionChange(selectedGroups) {
    // Handle single selection mode
    if (this.args.single && selectedGroups.length > 1) {
      selectedGroups = [selectedGroups[selectedGroups.length - 1]];
    }

    this.selectedGroups = selectedGroups;

    const groupNames = selectedGroups.map((group) => group.name);

    if (this.args.onChange) {
      this.args.onChange(groupNames.join(","));
    } else if (this.args.onChangeCallback) {
      this.args.onChangeCallback(groupNames.join(","), groupNames);
    }
  }

  @action
  compareGroups(a, b) {
    return a.name === b.name;
  }

  <template>
    <div class="group-selector-wrapper">
      <DMultiSelect
        @selection={{this.selectedGroups}}
        @loadFn={{this.loadFn}}
        @onChange={{this.handleSelectionChange}}
        @label={{this.placeholder}}
        @compareFn={{this.compareGroups}}
        @placement="bottom-start"
        @allowedPlacements={{array "top-start" "bottom-start"}}
        @matchTriggerWidth={{true}}
        @matchTriggerMinWidth={{true}}
        class="group-selector"
      >
        <:selection as |group|>
          {{group.name}}
        </:selection>
        <:result as |group|>
          {{group.name}}
        </:result>
      </DMultiSelect>
    </div>
  </template>
}
