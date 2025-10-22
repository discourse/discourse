import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";

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
            {{icon
              "magnifying-glass"
              class="sidebar__edit-navigation-menu__filter-input-icon"
            }}

            <input
              {{on "input" (withEventValue (fn (mut this.filter)))}}
              {{on "input" (withEventValue @onFilterInput)}}
              type="text"
              value={{this.filter}}
              placeholder={{@inputFilterPlaceholder}}
              autofocus="true"
              class="sidebar__edit-navigation-menu__filter-input-field"
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
            @action={{@save}}
            @label="save"
            @disabled={{@saving}}
            class="btn-primary sidebar__edit-navigation-menu__save-button"
          />

          {{#if @showResetDefaultsButton}}
            <DButton
              @action={{@resetToDefaults}}
              @label="sidebar.edit_navigation_modal_form.reset_to_defaults"
              @icon="arrow-rotate-left"
              @disabled={{@saving}}
              class="btn-flat btn-text sidebar__edit-navigation-menu__reset-defaults-button"
            />
          {{/if}}
        </div>
      </:footer>
    </DModal>
  </template>
}
