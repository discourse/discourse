// @ts-check
import Component from "@glimmer/component";
import { action } from "@ember/object";
/** @type {import("discourse/components/d-button.gjs").default} */
import DButton from "discourse/components/d-button";
/** @type {import("discourse/components/d-icon-grid-picker/content.gjs").default} */
import DIconGridPickerContent from "discourse/components/d-icon-grid-picker/content";
/** @type {import("discourse/float-kit/components/d-menu.gjs").default} */
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import dIcon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * A grid-based icon picker that displays available icons in a searchable
 * dropdown (desktop) or modal (mobile). Icons are fetched from the
 * `/svg-sprite/picker-search` endpoint and rendered in a 12-column grid.
 *
 * @param {string} value - The currently selected icon ID.
 * @param {Function} onChange - Called with the selected icon ID when an icon is picked.
 * @param {string[]} [favorites] - Icon IDs to display in a pinned favorites row above the grid.
 * @param {boolean} [showSelectedName] - When true, the selected favorite chip also displays
 *   the icon name alongside the icon.
 * @param {string} [btnClass] - Additional CSS class(es) for the trigger button.
 * @param {string} [label] - Optional text label shown next to the icon in the trigger button.
 * @param {boolean} [allowClear] - When true, shows a clear button next to the trigger
 *   in a split-button layout when a value is selected.
 * @param {string} [selectedTitle] - Translation key for the trigger button title when an
 *   icon is selected. Receives `{iconName}` as an interpolation variable.
 *   Defaults to "d_icon_grid_picker.selected_icon".
 * @param {string} [clearTitle] - Translation key for the clear button title.
 *   Defaults to "d_icon_grid_picker.clear".
 * @param {boolean} [modalForMobile] - Whether to show as a modal on mobile. Defaults to true.
 * @param {boolean} [inline] - When true, renders the menu inline instead of floating.
 * @param {Function} [onShow] - Called when the picker menu is opened.
 * @param {Function} [onClose] - Called when the picker menu is closed.
 */
export default class DIconGridPicker extends Component {
  /**
   * @returns {boolean} Whether to render as a modal on mobile devices.
   */
  get modalForMobile() {
    return this.args.modalForMobile ?? true;
  }

  get showClearButton() {
    return this.args.allowClear && this.args.value;
  }

  get triggerTitle() {
    if (!this.args.value) {
      return null;
    }
    const key = this.args.selectedTitle ?? "d_icon_grid_picker.selected_icon";
    return i18n(key, { iconName: this.args.value });
  }

  get clearTitle() {
    return this.args.clearTitle ?? "d_icon_grid_picker.clear";
  }

  /**
   * Stores the DMenu API instance so the content can close the menu
   * programmatically after an icon is selected.
   *
   * @param {Object} api - The DMenu API instance.
   */
  @action
  onRegisterMenu(api) {
    this.menu = api;
  }

  /**
   * Resets the filter when the menu is opened so the user always starts
   * with a clean search state. Also forwards to the external `@onShow` if provided.
   */
  @action
  onShow() {
    this.args.onShow?.();
  }

  /**
   * Handles icon selection by invoking the `@onChange` callback and closing
   * the menu/modal.
   *
   * @param {string} iconId - The selected icon's ID.
   */
  @action
  selectIcon(iconId) {
    this.args.onChange?.(iconId);
    this.menu?.close();
  }

  /**
   * Clears the current icon selection by invoking `@onChange` with null.
   */
  @action
  clearIcon() {
    this.args.onChange?.(null);
  }

  <template>
    <div
      class={{concatClass
        "d-icon-grid-picker"
        (if this.showClearButton "--has-clear")
      }}
    >
      <DMenu
        @title={{this.triggerTitle}}
        @triggerClass={{concatClass @btnClass}}
        @identifier="d-icon-grid-picker"
        @groupIdentifier="d-icon-grid-picker"
        @modalForMobile={{this.modalForMobile}}
        @maxWidth={{490}}
        @onShow={{this.onShow}}
        @onRegisterApi={{this.onRegisterMenu}}
        @onClose={{@onClose}}
        @inline={{@inline}}
      >
        <:trigger>
          {{#if @value}}
            {{dIcon @value}}
          {{/if}}

          {{#if @label}}
            <span class="d-button-label">{{@label}}</span>
          {{else}}
            &#8203;
          {{/if}}
        </:trigger>
        <:content>
          <DIconGridPickerContent
            @value={{@value}}
            @onSelect={{this.selectIcon}}
            @favorites={{@favorites}}
            @showSelectedName={{@showSelectedName}}
          />
        </:content>
      </DMenu>

      {{#if this.showClearButton}}
        <DButton
          class="btn-default d-icon-grid-picker__clear"
          @icon="xmark"
          @action={{this.clearIcon}}
          @title={{this.clearTitle}}
        />
      {{/if}}
    </div>
  </template>
}
