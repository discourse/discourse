import DBreadcrumbsContainer from "discourse/ui-kit/d-breadcrumbs-container";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DNavItem from "discourse/ui-kit/d-nav-item";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.showTopNav}}
    <div class="d-page-header">
      <DBreadcrumbsContainer />
      <DBreadcrumbsItem
        @path="/admin"
        @route="admin"
        @label={{i18n "admin_title"}}
      />
      <DBreadcrumbsItem
        @path="/admin/plugins"
        @route="adminPlugins"
        @label={{i18n "admin.config.plugins.title"}}
      />
      <div class="d-nav-submenu">
        <DHorizontalOverflowNav class="main-nav nav plugin-nav">
          <DNavItem @route="adminPlugins.index" @label="admin.plugins.title" />
          {{#each @controller.adminRoutes as |route|}}
            {{#if route.use_new_show_route}}
              <DNavItem
                @route={{route.full_location}}
                @label={{route.label}}
                @routeParam={{route.location}}
                @class="admin-plugin-tab-nav-item"
                data-plugin-nav-tab-id={{route.plugin_id}}
              />
            {{else}}
              <DNavItem
                @route={{route.full_location}}
                @label={{route.label}}
                @class="admin-plugin-tab-nav-item"
                data-plugin-nav-tab-id={{route.plugin_id}}
              />
            {{/if}}
          {{/each}}
        </DHorizontalOverflowNav>
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
