import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import DPageSubheader from "discourse/components/d-page-subheader";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import ColorSchemeListItem from "admin/components/color-scheme-list-item";

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

    <ul class="color-palette__list">
      {{! Show the built-in "Default" color scheme first }}
      <ColorSchemeListItem
        @scheme={{null}}
        @defaultTheme={{@controller.defaultTheme}}
        @isDefaultThemeColorScheme={{@controller.isDefaultThemeColorScheme}}
        @toggleUserSelectable={{@controller.toggleUserSelectable}}
        @setAsDefaultThemePalette={{@controller.setAsDefaultThemePalette}}
        @deleteColorScheme={{@controller.deleteColorScheme}}
      />

      {{#each @controller.model as |scheme|}}
        {{#unless scheme.is_base}}
          <ColorSchemeListItem
            @scheme={{scheme}}
            @defaultTheme={{@controller.defaultTheme}}
            @isDefaultThemeColorScheme={{@controller.isDefaultThemeColorScheme}}
            @toggleUserSelectable={{@controller.toggleUserSelectable}}
            @setAsDefaultThemePalette={{@controller.setAsDefaultThemePalette}}
            @deleteColorScheme={{@controller.deleteColorScheme}}
          />
        {{/unless}}
      {{/each}}
    </ul>
  </template>
);
