import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import withEventValue from "discourse/helpers/with-event-value";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class SidebarEditNavigationMenuModal extends Component {
  @tracked filter = "";
  @tracked filterDropdownValue = "all";
  filterDropdownContent = [
    {
      id: "all",
      name: i18n("sidebar.edit_navigation_modal_form.filter_dropdown.all"),
    },
    {
      id: "selected",
      name: i18n("sidebar.edit_navigation_modal_form.filter_dropdown.selected"),
    },
    {
      id: "unselected",
      name: i18n(
        "sidebar.edit_navigation_modal_form.filter_dropdown.unselected"
      ),
    },
  ];

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
      class="sidebar__edit-navigation-menu__modal --large"
      ...attributes
      @closeModal={{@closeModal}}
      @title={{i18n @title}}
    >
      <:belowModalTitle>
        <p class="sidebar__edit-navigation-menu__deselect-wrapper">
          <DButton
            class="btn-flat sidebar__edit-navigation-menu__deselect-button"
            @action={{@deselectAll}}
            @ariaLabel="sidebar.edit_navigation_modal_form.deselect_button_text"
            @label="sidebar.edit_navigation_modal_form.deselect_button_text"
          />

          {{@deselectAllText}}
        </p>
      </:belowModalTitle>

      <:belowHeader>
        <div class="sidebar__edit-navigation-menu__filter">
          <div class="sidebar__edit-navigation-menu__filter-input">
            {{dIcon
              "magnifying-glass"
              class="sidebar__edit-navigation-menu__filter-input-icon"
            }}

            <input
              autofocus="true"
              class="sidebar__edit-navigation-menu__filter-input-field"
              placeholder={{@inputFilterPlaceholder}}
              type="text"
              value={{this.filter}}
              {{on "input" (withEventValue (fn (mut this.filter)))}}
              {{on "input" (withEventValue @onFilterInput)}}
            />
          </div>

          <div class="sidebar__edit-navigation-menu__filter-dropdown-wrapper">
            <DropdownSelectBox
              class="sidebar__edit-navigation-menu__filter-dropdown"
              @content={{this.filterDropdownContent}}
              @onChange={{this.onFilterDropdownChange}}
              @options={{hash showCaret=true disabled=@loading}}
              @value={{this.filterDropdownValue}}
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
            class="btn-primary sidebar__edit-navigation-menu__save-button"
            @action={{@save}}
            @disabled={{@saving}}
            @label="save"
          />

          {{#if @showResetDefaultsButton}}
            <DButton
              class="btn-flat btn-text sidebar__edit-navigation-menu__reset-defaults-button"
              @action={{@resetToDefaults}}
              @disabled={{@saving}}
              @icon="arrow-rotate-left"
              @label="sidebar.edit_navigation_modal_form.reset_to_defaults"
            />
          {{/if}}
        </div>
      </:footer>
    </DModal>
  </template>
}
