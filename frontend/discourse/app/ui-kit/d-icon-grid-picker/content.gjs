// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  suppressMissingIconWarnings,
  SVG_NAMESPACE,
} from "discourse/lib/icon-library";
import { addExtraSpriteSymbols } from "discourse/lib/svg-sprite-loader";
import { eq } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DLoadMore from "discourse/ui-kit/d-load-more";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";

const ICON_TOOLTIP = "d-icon-grid-picker-icon";

/**
 * @typedef IconButtonSignature
 *
 * @property {object} Args
 *
 * @property {{id: string, symbol?: string}} Args.icon - The icon to render.
 * @property {boolean} [Args.selected] - Whether the icon is the currently selected value.
 * @property {(icon: {id: string, symbol?: string}) => void} Args.onSelect - Called with the picked icon.
 */

/** @extends {Component<IconButtonSignature>} */
class IconButton extends Component {
  /**
   * The icon's own `<symbol>`, for icons the page sprite cannot render. The
   * `<svg>` wrapper puts it in the SVG namespace when inserted as HTML, and it
   * renders in the cell that uses it, so it is torn down with that cell.
   */
  get symbol() {
    const { symbol } = this.args.icon;

    return symbol
      ? trustHTML(
          `<svg xmlns="${SVG_NAMESPACE}" style="display: none">${symbol}</svg>`
        )
      : null;
  }

  <template>
    <button
      type="button"
      role="option"
      aria-label={{@icon.id}}
      aria-selected={{if @selected "true" "false"}}
      class={{dConcatClass
        "d-icon-grid-picker__icon"
        (if @selected "--selected")
      }}
      data-icon-id={{@icon.id}}
      {{on "click" (fn @onSelect @icon)}}
    >
      {{this.symbol}}
      {{dIcon @icon.id}}
    </button>
  </template>
}

/**
 * The content panel rendered inside the DMenu dropdown or modal.
 * Handles icon search, favorites row, and the async-loaded icon grid.
 *
 * @param {string} value - The currently selected icon ID.
 * @param {Function} onSelect - Called with the selected icon ID when an icon is picked.
 * @param {string[]} [favorites] - Icon IDs to display in a pinned favorites row above the grid.
 * @param {boolean} [showSelectedName] - When true, the selected favorite chip also displays
 *   the icon name alongside the icon.
 * @param {boolean} [onlyAvailable] - When true, only offers icons available in the
 *   current SVG sprite set. Defaults to true.
 */
export default class DIconGridPickerContent extends Component {
  /** @type {import("discourse/float-kit/services/tooltip").default} */
  // @ts-ignore (incorrect no-initialization error)
  @service tooltip;

  @tracked filter = "";

  /** @type {Array<{id: string, symbol?: string}>?} Null until the first page resolves. */
  @tracked icons = null;

  @tracked hasMore = false;
  @tracked loadingMore = false;
  @tracked gridWrapper = null;

  registerGridWrapper = modifier((/** @type {HTMLElement} */ element) => {
    this.gridWrapper = element;
    return () => (this.gridWrapper = null);
  });

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
   * Modifier that shows a hover tooltip with the icon ID for any cell in the
   * grid. One delegated tooltip rather than one per cell, since the grid grows
   * by a page at a time. The selected chip is skipped: it shows its name inline.
   */
  iconTooltips = modifier((/** @type {HTMLElement} */ element) => {
    /** @type {HTMLElement?} */
    let current = null;

    const closeTooltip = () => {
      current = null;
      this.tooltip.close(ICON_TOOLTIP);
    };

    const onPointerOver = (/** @type {PointerEvent} */ event) => {
      const cell = /** @type {HTMLElement?} */ (
        /** @type {HTMLElement} */ (event.target).closest?.(
          ".d-icon-grid-picker__icon[data-icon-id]:not(.d-icon-grid-picker__selected-chip)"
        )
      );

      if (cell === current) {
        return;
      }

      current = cell;

      if (!cell) {
        this.tooltip.close(ICON_TOOLTIP);
        return;
      }

      this.tooltip.show(cell, {
        identifier: ICON_TOOLTIP,
        content: cell.dataset.iconId,
        placement: "top",
        fallbackPlacements: ["bottom"],
        animated: false,
      });
    };

    element.addEventListener("pointerover", onPointerOver);
    element.addEventListener("pointerleave", closeTooltip);

    return () => {
      element.removeEventListener("pointerover", onPointerOver);
      element.removeEventListener("pointerleave", closeTooltip);
      this.tooltip.close(ICON_TOOLTIP);
    };
  });

  #search = 0;

  #page = 0;

  constructor(owner, args) {
    super(owner, args);
    suppressMissingIconWarnings(this);
  }

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
   * Starts a new search: paging belongs to the search that produced it, so the
   * grid stops growing and any page still in flight is discarded on arrival.
   *
   * @param {string} value - The current input value.
   */
  @action
  setFilter(value) {
    this.filter = value;
    this.hasMore = false;
    this.loadingMore = false;
    this.#search++;
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
        let below = null;
        let nextRow = null;
        for (let i = idx + 1; i < allIcons.length; i++) {
          const el = allIcons[i];
          if (el.offsetTop <= target.offsetTop) {
            continue;
          }
          nextRow ??= el;
          if (el.offsetLeft === target.offsetLeft) {
            below = el;
            break;
          }
        }
        if (below) {
          below.focus();
        } else if (nextRow) {
          /* No exact column match (e.g. selected chip spans columns);
             jump to first icon on the next row */
          nextRow.focus();
        } else {
          this.loadMoreAndFocus();
        }
        break;
      }
      case "ArrowUp": {
        event.preventDefault();
        event.stopPropagation();
        let above = null;
        for (let i = idx - 1; i >= 0; i--) {
          const el = allIcons[i];
          if (el.offsetTop >= target.offsetTop) {
            continue;
          }
          if (el.offsetLeft === target.offsetLeft) {
            above = el;
            break;
          }
        }
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
    if (!this.icons) {
      return "";
    }

    return i18n(
      this.hasMore
        ? "d_icon_grid_picker.results_loaded"
        : "d_icon_grid_picker.results_count",
      { count: this.icons.length }
    );
  }

  /**
   * @param {number} page
   * @param {AbortSignal} [signal]
   * @returns {Promise<{icons: Array<{id: string, symbol?: string}>, has_more: boolean}>}
   */
  async #fetchPage(page, signal) {
    const request = /** @type {Promise<any> & {abort: () => void}} */ (
      ajax("/svg-sprite/picker-search", {
        data: {
          filter: this.filter.trim(),
          only_available: this.args.onlyAvailable ?? true,
          page,
        },
      })
    );

    signal?.addEventListener("abort", () => request.abort(), { once: true });

    return await request;
  }

  /**
   * Whether an async continuation still belongs to the live component and to
   * the search that started it.
   *
   * @param {number} search
   * @returns {boolean}
   */
  #isCurrent(search) {
    return this.#search === search && !this.isDestroying && !this.isDestroyed;
  }

  /**
   * Loads the first page of icons. Used as the `@asyncData` callback for the
   * `AsyncContent` loader, which debounces it and aborts superseded searches.
   *
   * @param {string} _filter - Tracked by `@context`; read from `this.filter`.
   * @param {{signal: AbortSignal}} options
   * @returns {Promise<Array<{id: string, symbol?: string}>>} The first page.
   */
  @action
  async fetchIcons(_filter, { signal }) {
    const search = this.#search;
    const { icons, has_more: hasMore } = await this.#fetchPage(0, signal);

    if (this.#isCurrent(search)) {
      this.icons = icons;
      this.hasMore = hasMore;
      this.#page = 0;
    }

    return icons;
  }

  @action
  async loadMore() {
    if (this.loadingMore || !this.hasMore) {
      return;
    }

    const search = this.#search;
    this.loadingMore = true;

    try {
      const { icons, has_more: hasMore } = await this.#fetchPage(
        this.#page + 1
      );

      if (!this.#isCurrent(search)) {
        return;
      }

      this.icons = [...this.icons, ...icons];
      this.hasMore = hasMore;
      this.#page++;
    } catch (error) {
      if (this.#isCurrent(search)) {
        this.hasMore = false;
        popupAjaxError(error);
      }
    } finally {
      if (this.#isCurrent(search)) {
        this.loadingMore = false;
      }
    }
  }

  /**
   * Loads the next page on behalf of the keyboard, which has no sentinel to
   * scroll into, and moves focus onto the first icon that arrives.
   */
  async loadMoreAndFocus() {
    const next = this.icons.length;
    await this.loadMore();

    schedule("afterRender", () => {
      /** @type {HTMLElement | undefined} */ (
        this.gridWrapper?.querySelector(
          `.d-icon-grid-picker__grid [data-icon-id="${this.icons[next]?.id}"]`
        )
      )?.focus();
    });
  }

  /**
   * Keeps the picked icon rendering once the picker closes, until the value is
   * saved and the icon becomes part of the sprite.
   *
   * @param {{id: string, symbol?: string}} icon
   */
  @action
  selectIcon(icon) {
    addExtraSpriteSymbols([icon]);
    this.args.onSelect(icon.id);
  }

  <template>
    {{! eslint-disable ember/template-no-invalid-interactive }}
    <div
      class="d-icon-grid-picker__content"
      style={{@iconColorStyle}}
      {{on "keydown" this.onKeyDown}}
    >
      <div class="d-icon-grid-picker__filter-container">
        <DFilterInput
          aria-label={{i18n "d_icon_grid_picker.search_label"}}
          aria-controls="d-icon-grid-picker-listbox"
          placeholder={{i18n "d_icon_grid_picker.search_placeholder"}}
          @value={{this.filter}}
          @filterAction={{withEventValue this.setFilter}}
          @onClearInput={{fn this.setFilter ""}}
          @icons={{hash left="magnifying-glass"}}
          @containerClass="d-icon-grid-picker__filter"
        />
      </div>

      <div
        class="d-icon-grid-picker__grid-wrapper"
        id="d-icon-grid-picker-listbox"
        {{this.registerGridWrapper}}
        {{this.iconTooltips}}
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
              {{! eslint-disable ember/template-require-context-role }}
              {{#if (eq favIcon @value)}}
                <button
                  type="button"
                  role="option"
                  aria-label={{favIcon}}
                  aria-selected="true"
                  class={{dConcatClass
                    "d-icon-grid-picker__icon --selected"
                    (if @showSelectedName "d-icon-grid-picker__selected-chip")
                  }}
                  data-icon-id={{favIcon}}
                  {{this.snapToGrid}}
                  {{on "click" (fn this.selectIcon (hash id=favIcon))}}
                >
                  {{dIcon favIcon}}
                  {{#if @showSelectedName}}
                    <span
                      class="d-icon-grid-picker__selected-name"
                    >{{favIcon}}</span>
                  {{/if}}
                </button>
              {{else}}
                <IconButton
                  @icon={{hash id=favIcon}}
                  @onSelect={{this.selectIcon}}
                />
              {{/if}}
            {{/each}}
          </div>
        {{/if}}

        <div class="d-icon-grid-picker__grid" role="presentation">
          <DAsyncContent
            @asyncData={{this.fetchIcons}}
            @context={{this.filter}}
            @debounce={{true}}
          >
            <:loading>
              <div class="d-icon-grid-picker__loading">
                {{dLoadingSpinner}}
              </div>
            </:loading>
            <:content>
              {{#each this.icons as |item|}}
                <IconButton
                  @icon={{item}}
                  @selected={{eq item.id @value}}
                  @onSelect={{this.selectIcon}}
                />
              {{/each}}
            </:content>
            <:empty>
              <div class="d-icon-grid-picker__empty" role="status">
                {{i18n "d_icon_grid_picker.no_results"}}
              </div>
            </:empty>
          </DAsyncContent>
        </div>

        {{#if this.loadingMore}}
          <div class="d-icon-grid-picker__loading-more">
            {{dLoadingSpinner}}
          </div>
        {{/if}}

        {{#if this.hasMore}}
          <DLoadMore
            @action={{this.loadMore}}
            @isLoading={{this.loadingMore}}
            @root={{this.gridWrapper}}
            class="d-icon-grid-picker__sentinel"
          />
        {{/if}}
      </div>

      <div class="sr-only" aria-live="polite" role="status">
        {{this.resultAnnouncement}}
      </div>
    </div>
  </template>
}
