import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import AsyncContent from "discourse/components/async-content";
import FilterInput from "discourse/components/filter-input";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import dIcon from "discourse/helpers/d-icon";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class DIconGridPicker extends Component {
  @service tooltip;

  @tracked filter = "";

  snapToGrid = modifier((element) => {
    const CELL = 36;
    const GAP = 2;
    const stride = CELL + GAP;

    /* Temporarily unconstrain width to measure natural content width */
    element.style.width = "max-content";
    const contentWidth = element.getBoundingClientRect().width;

    const span = Math.ceil(contentWidth / stride);
    element.style.gridColumn = `span ${span}`;
    /* Fill the spanned grid area (inline style overrides CSS width: 36px) */
    element.style.width = "100%";
  });

  registerIconTooltip = modifier((element) => {
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

  get hasFavorites() {
    return this.displayFavorites.length > 0 && !this.filter;
  }

  @action
  onShow() {
    this.filter = "";
  }

  @action
  onFilterInput(value) {
    this.filter = value;
  }

  @action
  clearFilter() {
    this.filter = "";
  }

  @action
  async fetchIcons(filter) {
    return ajax("/svg-sprite/picker-search", {
      data: { filter: filter || "", only_available: true },
    });
  }

  @action
  selectIcon(iconId, closeMenu) {
    this.args.onChange?.(iconId);
    closeMenu?.();
  }

  <template>
    <DMenu
      @identifier="d-icon-grid-picker"
      @modalForMobile={{true}}
      @onShow={{this.onShow}}
      @maxWidth={{490}}
      class={{concatClass
        "d-icon-grid-picker__trigger btn-flat btn-small"
        @class
      }}
      ...attributes
    >
      <:trigger>
        {{dIcon (if @value @value "question")}}
      </:trigger>
      <:content as |menuArgs|>
        <div class="d-icon-grid-picker__content">
          <div class="d-icon-grid-picker__filter-container">
            <FilterInput
              @value={{this.filter}}
              @filterAction={{withEventValue this.onFilterInput}}
              @onClearInput={{this.clearFilter}}
              @icons={{hash left="magnifying-glass"}}
              @containerClass="d-icon-grid-picker__filter"
              placeholder={{i18n "d_icon_grid_picker.search_placeholder"}}
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
                        (if
                          @showSelectedName "d-icon-grid-picker__selected-chip"
                        )
                      }}
                      data-icon-id={{favIcon}}
                      role="button"
                      {{this.registerIconTooltip}}
                      {{this.snapToGrid}}
                      {{on "click" (fn this.selectIcon favIcon menuArgs.close)}}
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
                      {{on "click" (fn this.selectIcon favIcon menuArgs.close)}}
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
                      {{on "click" (fn this.selectIcon item.id menuArgs.close)}}
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
      </:content>
    </DMenu>
  </template>
}
