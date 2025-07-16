import { hash } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import { or } from "truth-helpers";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageHeader from "discourse/components/d-page-header";
import DPageSubheader from "discourse/components/d-page-subheader";
import DSelect from "discourse/components/d-select";
import FilterInput from "discourse/components/filter-input";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import ColorPaletteListItem from "admin/components/color-palette-list-item";

export default RouteTemplate(
  <template>
    <DPageHeader @hideTabs={{true}}>
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/customize/colors"
          @label={{i18n "admin.config.color_palettes.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <DPageSubheader
      @titleLabel={{i18n "admin.config.color_palettes.title"}}
      @descriptionLabel={{i18n
        "admin.config.color_palettes.header_description"
      }}
      @learnMoreUrl="https://meta.discourse.org/t/allow-users-to-select-new-color-palettes/60857"
    >
      <:actions as |actions|>
        <PluginOutlet
          @name="admin-customize-colors-new-button"
          @outletArgs={{lazyHash actions=actions controller=@controller}}
        >
          <actions.Primary
            @label="admin.customize.new"
            @action={{@controller.newColorScheme}}
            @icon="plus"
          />
        </PluginOutlet>
      </:actions>
    </DPageSubheader>

    {{#if @controller.showFilters}}
      <div class="color-palette__filters">
        <FilterInput
          placeholder={{i18n
            "admin.customize.colors.filters.search_placeholder"
          }}
          @filterAction={{@controller.onFilterChange}}
          @value={{@controller.filterValue}}
          class="admin-filter__input"
          @icons={{hash left="magnifying-glass"}}
        />
        <DSelect
          @value={{@controller.typeFilter}}
          @includeNone={{false}}
          @onChange={{@controller.onTypeFilterChange}}
          as |select|
        >
          {{#each @controller.typeFilterOptions as |option|}}
            <select.Option @value={{option.value}}>
              {{option.label}}
            </select.Option>
          {{/each}}
        </DSelect>
      </div>
    {{/if}}

    <ul class="color-palette__list">
      {{! show the built-in "default" color scheme }}
      {{#if @controller.showBuiltInDefault}}
        <ColorPaletteListItem
          @scheme={{null}}
          @defaultTheme={{@controller.defaultTheme}}
          @isDefaultThemeColorScheme={{@controller.isDefaultThemeColorScheme}}
          @toggleUserSelectable={{@controller.toggleUserSelectable}}
          @setAsDefaultThemePalette={{@controller.setAsDefaultThemePalette}}
          @deleteColorScheme={{@controller.deleteColorScheme}}
        />
      {{/if}}

      {{#each @controller.filteredColorSchemes as |scheme|}}
        <ColorPaletteListItem
          @scheme={{scheme}}
          @defaultTheme={{@controller.defaultTheme}}
          @isDefaultThemeColorScheme={{@controller.isDefaultThemeColorScheme}}
          @toggleUserSelectable={{@controller.toggleUserSelectable}}
          @setAsDefaultThemePalette={{@controller.setAsDefaultThemePalette}}
          @deleteColorScheme={{@controller.deleteColorScheme}}
        />
      {{/each}}
    </ul>

    {{#if @controller.showFilters}}
      {{#unless
        (or
          @controller.filteredColorSchemes.length @controller.showBuiltInDefault
        )
      }}
        <div class="color-palette__no-results">
          <h3>{{i18n "admin.customize.colors.filters.no_results"}}</h3>
          <DButton
            @icon="arrow-rotate-left"
            @label="admin.customize.colors.filters.reset"
            @action={{@controller.resetFilters}}
            class="btn-default"
          />
        </div>
      {{/unless}}
    {{/if}}
  </template>
);
