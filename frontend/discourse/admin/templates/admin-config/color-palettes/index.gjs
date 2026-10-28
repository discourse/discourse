import { trustHTML } from "@ember/template";
import ColorPaletteListItem from "discourse/admin/components/color-palette-list-item";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import getUrl from "discourse/lib/get-url";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import DPageHeader from "discourse/ui-kit/d-page-header";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

const FILTER_MINIMUM = 8;

export default <template>
  <DPageHeader @hideTabs={{true}}>
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.color_palettes.title"}}
        @path="/admin/config/colors"
      />
    </:breadcrumbs>
  </DPageHeader>

  <DPageSubheader
    @descriptionLabel={{i18n "admin.config.color_palettes.header_description"}}
    @learnMoreUrl="https://meta.discourse.org/t/allow-users-to-select-new-color-palettes/60857"
    @titleLabel={{i18n "admin.config.color_palettes.title"}}
  >
    <:actions as |actions|>
      <PluginOutlet
        @name="admin-customize-colors-new-button"
        @outletArgs={{lazyHash actions=actions controller=@controller}}
      >
        <actions.Primary
          class="create-new-palette"
          @action={{@controller.newColorScheme}}
          @icon="plus"
          @label="admin.customize.new"
        />
      </PluginOutlet>
    </:actions>
  </DPageSubheader>

  {{#if @controller.preferencesWarningMessage}}
    <p class="color-palette__warning">
      {{#if @controller.preferencesWarningMessage.usingNonDefaultTheme}}
        {{trustHTML
          (i18n
            "admin.customize.colors.non_default_theme_warning"
            themeName=@controller.preferencesWarningMessage.themeName
            link=(getUrl "/my/preferences/interface")
          )
        }}
      {{else}}
        {{trustHTML
          (i18n
            "admin.customize.colors.custom_schemes_warning"
            colorModes=@controller.preferencesWarningMessage.colorModes
            link=(getUrl "/my/preferences/interface")
          )
        }}
      {{/if}}
    </p>
  {{/if}}

  <DFilterControls
    @array={{@controller.displayedPalettes}}
    @dropdownFilterQueryParam="type"
    @dropdownOptions={{@controller.dropdownOptions}}
    @inputPlaceholder={{i18n
      "admin.customize.colors.filters.search_placeholder"
    }}
    @minItemsForFilter={{FILTER_MINIMUM}}
    @noResultsMessage={{i18n "admin.customize.colors.filters.no_results"}}
    @searchableProps={{@controller.searchableProps}}
    @textFilterQueryParam="filter"
  >
    <:content as |schemes|>
      <ul class="color-palette__list">
        {{#each schemes as |scheme|}}
          <ColorPaletteListItem
            @defaultTheme={{@controller.defaultTheme}}
            @deleteColorScheme={{@controller.deleteColorScheme}}
            @isDefaultThemeDarkColorScheme={{@controller.isDefaultThemeDarkColorScheme}}
            @isDefaultThemeLightColorScheme={{@controller.isDefaultThemeLightColorScheme}}
            @scheme={{scheme}}
            @setAsDefaultThemePalette={{@controller.setAsDefaultThemePalette}}
            @toggleUserSelectable={{@controller.toggleUserSelectable}}
          />
        {{/each}}
      </ul>
    </:content>
  </DFilterControls>
</template>
