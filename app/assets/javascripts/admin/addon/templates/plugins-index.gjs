import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import AdminFilterControls from "admin/components/admin-filter-controls";
import AdminPluginsList from "admin/components/admin-plugins-list";

export default RouteTemplate(
  <template>
    <div class="admin-plugins-list-container">

      <DPageHeader
        @titleLabel={{i18n "admin.config.plugins.title"}}
        @descriptionLabel={{htmlSafe
          (concat
            (i18n "admin.config.plugins.header_description")
            '<a class="admin-plugins-howto" href="https://meta.discourse.org/t/install-a-plugin/19157">'
            (i18n "admin.plugins.howto")
            "</a>"
          )
        }}
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
          <DBreadcrumbsItem
            @path="/admin/plugins"
            @label={{i18n "admin.plugins.title"}}
          />
        </:breadcrumbs>
        <:tabs>
          <NavItem @route="adminPlugins.index" @label="admin.plugins.title" />
          {{#each @controller.adminRoutes as |route|}}
            {{#if route.use_new_show_route}}
              <NavItem
                @route={{route.full_location}}
                @label={{route.label}}
                @routeParam={{route.location}}
                @class="admin-plugin-tab-nav-item"
                data-plugin-nav-tab-id={{route.plugin_id}}
              />
            {{else}}
              <NavItem
                @route={{route.full_location}}
                @label={{route.label}}
                @class="admin-plugin-tab-nav-item"
                data-plugin-nav-tab-id={{route.plugin_id}}
              />
            {{/if}}
          {{/each}}
        </:tabs>
      </DPageHeader>

      {{#if @controller.model.length}}
        <AdminFilterControls
          @array={{@controller.model}}
          @searchableProps={{@controller.searchableProps}}
          @dropdownOptions={{@controller.dropdownOptions}}
          @inputPlaceholder={{i18n "admin.plugins.filters.search_placeholder"}}
          @noResultsMessage={{i18n "admin.plugins.filters.no_results"}}
          as |filteredPlugins|
        >
          <AdminPluginsList @plugins={{filteredPlugins}} />
        </AdminFilterControls>
      {{else}}
        <p>{{i18n "admin.plugins.none_installed"}}</p>
      {{/if}}

      <span>
        <PluginOutlet
          @name="admin-below-plugins-index"
          @connectorTagName="div"
          @outletArgs={{lazyHash model=@controller.model}}
        />
      </span>
    </div>
  </template>
);
