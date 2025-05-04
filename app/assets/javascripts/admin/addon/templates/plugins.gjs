import RouteTemplate from "ember-route-template";
import DBreadcrumbsContainer from "discourse/components/d-breadcrumbs-container";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{#if @controller.showTopNav}}
      <div class="d-page-header">
        <DBreadcrumbsContainer />
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/plugins"
          @label={{i18n "admin.config.plugins.title"}}
        />
        <div class="d-nav-submenu">
          <HorizontalOverflowNav class="main-nav nav plugin-nav">
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
          </HorizontalOverflowNav>
        </div>
      </div>
    {{/if}}

    <div class="admin-config-page -no-header">
      {{#each @controller.brokenAdminRoutes as |route|}}
        <div class="alert alert-error">
          {{i18n "admin.plugins.broken_route" name=(i18n route.label)}}
        </div>
      {{/each}}

      {{outlet}}
    </div>
  </template>
);
