import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";

export default class extends Component {
  @tracked filter = "";
  @tracked filterDropdownValue = "all";

  filterDropdownContent = [
    {
      id: "all",
      name: I18n.t("sidebar.edit_navigation_modal_form.filter_dropdown.all"),
    },
    {
      id: "selected",
      name: I18n.t(
        "sidebar.edit_navigation_modal_form.filter_dropdown.selected"
      ),
    },
    {
      id: "unselected",
      name: I18n.t(
        "sidebar.edit_navigation_modal_form.filter_dropdown.unselected"
      ),
    },
  ];

  @action
  onFilterInput(input) {
    this.args.onFilterInput(input.target.value);
  }

  @action
  onFilterDropdownChange(value) {
    this.filterDropdownValue = value;

    switch (value) {
      case "all":
        this.args.resetFilter();
        break;
      case "selected":
        this.args.filterSelected();
        break;
      case "unselected":
        this.args.filterUnselected();
        break;
    }
  }

  <template>
    <DModal
      @title={{i18n @title}}
      @closeModal={{@closeModal}}
      class="sidebar__edit-navigation-menu__modal -large"
      ...attributes
    >
      <:belowModalTitle>
        <p class="sidebar__edit-navigation-menu__deselect-wrapper">
          <DButton
            @label="sidebar.edit_navigation_modal_form.deselect_button_text"
            @ariaLabel="sidebar.edit_navigation_modal_form.deselect_button_text"
            @action={{@deselectAll}}
            class="btn-flat sidebar__edit-navigation-menu__deselect-button"
          />

          {{@deselectAllText}}
        </p>
      </:belowModalTitle>

      <:belowHeader>
        <div class="sidebar__edit-navigation-menu__filter">
          <div class="sidebar__edit-navigation-menu__filter-input">
            {{dIcon
              "search"
              class="sidebar__edit-navigation-menu__filter-input-icon"
            }}

            <Input
              class="sidebar__edit-navigation-menu__filter-input-field"
              placeholder={{@inputFilterPlaceholder}}
              @type="text"
              @value={{this.filter}}
              {{on "input" this.onFilterInput}}
              autofocus="true"
            />
          </div>

          <div class="sidebar__edit-navigation-menu__filter-dropdown-wrapper">
            <DropdownSelectBox
              @value={{this.filterDropdownValue}}
              @content={{this.filterDropdownContent}}
              @onChange={{this.onFilterDropdownChange}}
              @options={{hash showCaret=true disabled=@loading}}
              class="sidebar__edit-navigation-menu__filter-dropdown"
            />
          </div>
        </div>
      </:belowHeader>

      <:body>
        {{yield}}
      </:body>

      <:footer>
        <div class="sidebar__edit-navigation-menu__footer">
          <DButton
            @label="save"
            @disabled={{@saving}}
            @action={{@save}}
            class="btn-primary sidebar__edit-navigation-menu__save-button"
          />

          {{#if @showResetDefaultsButton}}
            <DButton
              @icon="undo"
              @label="sidebar.edit_navigation_modal_form.reset_to_defaults"
              @disabled={{@saving}}
              @action={{@resetToDefaults}}
              class="btn-flat btn-text sidebar__edit-navigation-menu__reset-defaults-button"
            />
          {{/if}}
        </div>
      </:footer>
    </DModal>
  </template>
}
