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
import icon from "discourse/helpers/d-icon";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

/* Module-level cache for the unfiltered icon list, keyed by onlyAvailable flag */
const unfilteredIconCache = new Map();

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
  /** @type {import("discourse/float-kit/services/tooltip").default} */
  // @ts-ignore (incorrect no-initialization error)
  @service tooltip;

  @tracked filter = "";
  @tracked resultCount = null;

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
   * Handles arrow key navigation within the icon grid. Uses position-based
   * matching (offsetTop/offsetLeft) for vertical movement so it works
   * regardless of how many columns the grid renders.
   *
   * @param {KeyboardEvent} event
   */
  @action
  onGridKeyDown(event) {
    const target = /** @type {HTMLElement} */ (event.target);
    if (!target.classList.contains("d-icon-grid-picker__icon")) {
      return;
    }

    const wrapper = /** @type {HTMLElement!} */ (
      target.closest(".d-icon-grid-picker__grid-wrapper")
    );
    const icons = wrapper.querySelectorAll(".d-icon-grid-picker__icon");
    const allIcons = /** @type {HTMLElement[]} */ ([...icons]);
    const idx = allIcons.indexOf(target);

    switch (event.key) {
      case "ArrowRight": {
        event.preventDefault();
        const next = allIcons[idx + 1];
        if (next) {
          next.focus();
        }
        break;
      }
      case "ArrowLeft": {
        event.preventDefault();
        const prev = allIcons[idx - 1];
        if (prev) {
          prev.focus();
        } else {
          this.focusFilter(wrapper);
        }
        break;
      }
      case "ArrowDown": {
        event.preventDefault();
        event.stopPropagation();
        const below = allIcons
          .filter((el) => el.offsetTop > target.offsetTop)
          .find((el) => el.offsetLeft === target.offsetLeft);
        if (below) {
          below.focus();
        } else {
          /* No exact column match (e.g. selected chip spans columns);
             jump to first icon on the next row */
          const nextRow = allIcons.find(
            (el) => el.offsetTop > target.offsetTop
          );
          nextRow?.focus();
        }
        break;
      }
      case "ArrowUp": {
        event.preventDefault();
        event.stopPropagation();
        const above = [...allIcons]
          .reverse()
          .filter((el) => el.offsetTop < target.offsetTop)
          .find((el) => el.offsetLeft === target.offsetLeft);
        if (above) {
          above.focus();
        } else {
          this.focusFilter(wrapper);
        }
        break;
      }
    }
  }

  /**
   * Unified keydown handler on the content root. Delegates to grid
   * navigation or filter-to-grid focus depending on the event target.
   *
   * @param {KeyboardEvent} event
   */
  @action
  onKeyDown(event) {
    const target = /** @type {HTMLElement} */ (event.target);
    if (
      target.classList.contains("filter-input") &&
      event.key === "ArrowDown"
    ) {
      event.preventDefault();
      /** @type {HTMLElement | null} */ (
        target
          .closest(".d-icon-grid-picker__content")
          ?.querySelector(".d-icon-grid-picker__icon")
      )?.focus();
      return;
    }

    this.onGridKeyDown(event);
  }

  /**
   * @param {HTMLElement} wrapper
   */
  focusFilter(wrapper) {
    /** @type {HTMLInputElement?} */ (
      wrapper
        .closest(".d-icon-grid-picker__content")
        ?.querySelector(".filter-input")
    )?.focus();
  }

  get resultAnnouncement() {
    if (this.resultCount === null) {
      return "";
    }
    return i18n("d_icon_grid_picker.results_count", {
      count: this.resultCount,
    });
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
    const onlyAvailable = this.args.onlyAvailable ?? true;

    if (!filter && unfilteredIconCache.has(onlyAvailable)) {
      const cached = unfilteredIconCache.get(onlyAvailable);
      this.resultCount = cached.length;
      return cached;
    }

    const icons = await ajax("/svg-sprite/picker-search", {
      data: { filter: filter || "", only_available: onlyAvailable },
    });

    if (!filter) {
      unfilteredIconCache.set(onlyAvailable, icons);
    }

    this.resultCount = icons.length;
    return icons;
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      class="d-icon-grid-picker__content"
      style={{@iconColorStyle}}
      {{on "keydown" this.onKeyDown}}
    >
      <div class="d-icon-grid-picker__filter-container">
        <FilterInput
          {{! @glint-expect-error: FilterInput lacks Element type declaration }}
          aria-label={{i18n "d_icon_grid_picker.search_placeholder"}}
          aria-controls="d-icon-grid-picker-listbox"
          placeholder={{i18n "d_icon_grid_picker.search_placeholder"}}
          @value={{this.filter}}
          @filterAction={{withEventValue this.onFilterInput}}
          @onClearInput={{this.clearFilter}}
          @icons={{hash left="magnifying-glass"}}
          @containerClass="d-icon-grid-picker__filter"
        />
      </div>

      <div
        class="d-icon-grid-picker__grid-wrapper"
        id="d-icon-grid-picker-listbox"
        role="listbox"
        aria-label={{i18n "d_icon_grid_picker.select_icon"}}
      >
        {{#if this.hasFavorites}}
          <div
            class="d-icon-grid-picker__favorites"
            role="group"
            aria-label={{i18n "d_icon_grid_picker.favorites"}}
          >
            {{#each this.displayFavorites as |favIcon|}}
              {{! template-lint-disable require-context-role }}
              {{#if (eq favIcon @value)}}
                <button
                  type="button"
                  role="option"
                  aria-label={{favIcon}}
                  aria-selected="true"
                  class={{concatClass
                    "d-icon-grid-picker__icon --selected"
                    (if @showSelectedName "d-icon-grid-picker__selected-chip")
                  }}
                  data-icon-id={{favIcon}}
                  {{this.registerIconTooltip}}
                  {{this.snapToGrid}}
                  {{on "click" (fn @onSelect favIcon)}}
                >
                  {{icon favIcon}}
                  {{#if @showSelectedName}}
                    <span
                      class="d-icon-grid-picker__selected-name"
                    >{{favIcon}}</span>
                  {{/if}}
                </button>
              {{else}}
                {{! template-lint-disable require-context-role }}
                <button
                  type="button"
                  role="option"
                  aria-label={{favIcon}}
                  aria-selected="false"
                  class="d-icon-grid-picker__icon"
                  data-icon-id={{favIcon}}
                  {{this.registerIconTooltip}}
                  {{on "click" (fn @onSelect favIcon)}}
                >
                  {{icon favIcon}}
                </button>
              {{/if}}
            {{/each}}
          </div>
        {{/if}}

        <div class="d-icon-grid-picker__grid" role="presentation">
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
                {{! template-lint-disable require-context-role }}
                <button
                  type="button"
                  role="option"
                  aria-label={{item.id}}
                  aria-selected={{if (eq item.id @value) "true" "false"}}
                  class={{concatClass
                    "d-icon-grid-picker__icon"
                    (if (eq item.id @value) "--selected")
                  }}
                  data-icon-id={{item.id}}
                  {{this.registerIconTooltip}}
                  {{on "click" (fn @onSelect item.id)}}
                >
                  {{icon item.id}}
                </button>
              {{/each}}
            </:content>
            <:empty>
              <div class="d-icon-grid-picker__empty" role="status">
                {{i18n "d_icon_grid_picker.no_results"}}
              </div>
            </:empty>
          </AsyncContent>
        </div>
      </div>
      <div class="sr-only" aria-live="polite" role="status">
        {{this.resultAnnouncement}}
      </div>
    </div>
  </template>
}
