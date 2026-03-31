// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
/** @type {import("discourse/components/async-content.gjs")} */
import AsyncContent from "discourse/components/async-content";
import FilterInput from "discourse/components/filter-input";
import concatClass from "discourse/helpers/concat-class";
import dIcon from "discourse/helpers/d-icon";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

/**
 * The content panel rendered inside the DMenu dropdown or modal.
 * Handles icon search, favorites row, and the async-loaded icon grid.
 *
 * @param {string} value - The currently selected icon ID.
 * @param {Function} onSelect - Called with the selected icon ID when an icon is picked.
 * @param {string[]} [favorites] - Icon IDs to display in a pinned favorites row above the grid.
 * @param {boolean} [showSelectedName] - When true, the selected favorite chip also displays
 *   the icon name alongside the icon.
 * @param {boolean} [onlyAvailable] - When true, only shows icons available in the
 *   current SVG sprite set. Defaults to true.
 */
export default class DIconGridPickerContent extends Component {
  @service tooltip;

  @tracked filter = "";

  /**
   * Modifier that measures the natural content width of the selected-chip element
   * and snaps it to the nearest number of grid columns so it aligns with the
   * grid without overflowing. Cell size and gap are read from the
   * `--icon-grid-cell` and `--icon-grid-gap` CSS custom properties.
   */
  snapToGrid = modifier((/** @type {HTMLElement} */ element) => {
    const styles = getComputedStyle(element);
    const cell = parseFloat(styles.getPropertyValue("--icon-grid-cell"));
    const gap = parseFloat(styles.getPropertyValue("--icon-grid-gap"));
    const stride = cell + gap;

    /* Temporarily unconstrain width to measure natural content width */
    element.style.width = "max-content";
    const contentWidth = element.getBoundingClientRect().width;

    const span = Math.ceil(contentWidth / stride);
    element.style.gridColumn = `span ${span}`;
    /* Fill the spanned grid area (inline style overrides the CSS cell width) */
    element.style.width = "100%";
  });

  /**
   * Modifier that registers a hover tooltip showing the icon ID on each grid cell.
   * Skips the selected-chip element since it already displays the name inline.
   */
  registerIconTooltip = modifier((/** @type {HTMLElement} */ element) => {
    const iconId = element.dataset.iconId;
    if (
      !iconId ||
      element.classList.contains("d-icon-grid-picker__selected-chip")
    ) {
      return;
    }

    const instance = this.tooltip.register(element, {
      content: iconId,
      placement: "top",
      fallbackPlacements: ["bottom"],
      triggers: ["hover"],
      animated: false,
    });

    return () => instance.destroy();
  });

  /**
   * Returns the list of favorite icon IDs to display, with the currently
   * selected icon always first (deduplicated against the favorites array).
   *
   * @returns {string[]} Ordered array of icon IDs for the favorites row.
   */
  get displayFavorites() {
    const favs = this.args.favorites || [];
    const value = this.args.value;
    if (!value && !favs.length) {
      return [];
    }
    const result = value ? [value] : [];
    for (const f of favs) {
      if (!result.includes(f)) {
        result.push(f);
      }
    }
    return result;
  }

  /**
   * Whether the favorites row should be visible. Hidden when the user is
   * actively filtering, since search results replace the favorites section.
   *
   * @returns {boolean}
   */
  get hasFavorites() {
    return this.displayFavorites.length > 0 && !this.filter;
  }

  /**
   * Updates the tracked filter string as the user types in the search input.
   *
   * @param {string} value - The current input value.
   */
  @action
  onFilterInput(value) {
    this.filter = value;
  }

  /**
   * Clears the search filter, restoring the full icon list and favorites row.
   */
  @action
  clearFilter() {
    this.filter = "";
  }

  /**
   * Fetches icons from the server, optionally filtered by a search term.
   * Used as the `@asyncData` callback for the `AsyncContent` loader.
   *
   * @param {string} filter - The search string to filter icons by name.
   * @returns {Promise<Array<{id: string, symbol: string}>>} Array of matching icons.
   */
  @action
  async fetchIcons(filter) {
    return ajax("/svg-sprite/picker-search", {
      data: {
        filter: filter || "",
        only_available: this.args.onlyAvailable ?? true,
      },
    });
  }

  <template>
    <div class="d-icon-grid-picker__content" style={{@iconColorStyle}}>
      <div class="d-icon-grid-picker__filter-container">
        <FilterInput
          {{! @glint-expect-error: FilterInput lacks Element type declaration }}
          placeholder={{i18n "d_icon_grid_picker.search_placeholder"}}
          @value={{this.filter}}
          @filterAction={{withEventValue this.onFilterInput}}
          @onClearInput={{this.clearFilter}}
          @icons={{hash left="magnifying-glass"}}
          @containerClass="d-icon-grid-picker__filter"
        />
      </div>

      <div class="d-icon-grid-picker__grid-wrapper">
        {{#if this.hasFavorites}}
          <div class="d-icon-grid-picker__favorites">
            {{#each this.displayFavorites as |favIcon|}}
              {{! template-lint-disable no-invalid-interactive }}
              {{#if (eq favIcon @value)}}
                <span
                  class={{concatClass
                    "d-icon-grid-picker__icon --selected"
                    (if @showSelectedName "d-icon-grid-picker__selected-chip")
                  }}
                  data-icon-id={{favIcon}}
                  role="button"
                  {{this.registerIconTooltip}}
                  {{this.snapToGrid}}
                  {{on "click" (fn @onSelect favIcon)}}
                >
                  {{dIcon favIcon}}
                  {{#if @showSelectedName}}
                    <span
                      class="d-icon-grid-picker__selected-name"
                    >{{favIcon}}</span>
                  {{/if}}
                </span>
              {{else}}
                <span
                  class="d-icon-grid-picker__icon"
                  data-icon-id={{favIcon}}
                  role="button"
                  {{this.registerIconTooltip}}
                  {{on "click" (fn @onSelect favIcon)}}
                >
                  {{dIcon favIcon}}
                </span>
              {{/if}}
            {{/each}}
          </div>
        {{/if}}

        <div class="d-icon-grid-picker__grid">
          <AsyncContent
            @asyncData={{this.fetchIcons}}
            @context={{this.filter}}
            @debounce={{true}}
          >
            <:loading>
              <div class="d-icon-grid-picker__loading">
                <div class="spinner"></div>
              </div>
            </:loading>
            <:content as |icons|>
              {{#each icons as |item|}}
                {{! template-lint-disable no-invalid-interactive }}
                <span
                  class={{concatClass
                    "d-icon-grid-picker__icon"
                    (if (eq item.id @value) "--selected")
                  }}
                  data-icon-id={{item.id}}
                  role="button"
                  {{this.registerIconTooltip}}
                  {{on "click" (fn @onSelect item.id)}}
                >
                  {{dIcon item.id}}
                </span>
              {{/each}}
            </:content>
            <:empty>
              <div class="d-icon-grid-picker__empty">
                {{i18n "d_icon_grid_picker.no_results"}}
              </div>
            </:empty>
          </AsyncContent>
        </div>
      </div>
    </div>
  </template>
}
