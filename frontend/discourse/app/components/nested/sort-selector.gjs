import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const SORT_OPTIONS = [
  { value: "top", labelKey: "nested_replies.sort.top" },
  { value: "new", labelKey: "nested_replies.sort.new" },
  { value: "old", labelKey: "nested_replies.sort.old" },
];

export default class NestedSortSelector extends Component {
  sortOptions = SORT_OPTIONS;

  get currentSortLabel() {
    const current = this.sortOptions.find(
      (option) => option.value === this.args.current
    );
    return i18n(current?.labelKey || "nested_replies.sort.top");
  }

  @action
  onRegisterApi(api) {
    this.menuApi = api;
  }

  @action
  changeSort(sort) {
    this.args.onChange(sort);
    this.menuApi.close();
  }

  <template>
    <div class="nested-sort-selector">
      <span class="nested-sort-selector__label">
        {{i18n "nested_replies.sort.label"}}:
      </span>

      <DMenu
        @identifier="nested-sort-selector"
        @onRegisterApi={{this.onRegisterApi}}
        @placement="bottom-start"
        @triggerClass="btn-flat nested-sort-selector__trigger"
      >
        <:trigger>
          <span class="d-button-label">{{this.currentSortLabel}}</span>
          {{dIcon "angle-down"}}
        </:trigger>

        <:content>
          <DDropdownMenu as |dropdown|>
            {{#each this.sortOptions as |option|}}
              <dropdown.item>
                <DButton
                  class={{if (eq @current option.value) "is-selected"}}
                  @translatedLabel={{i18n option.labelKey}}
                  @action={{fn this.changeSort option.value}}
                />
              </dropdown.item>
            {{/each}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    </div>
  </template>
}
