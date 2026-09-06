import DBreadcrumbsContainer from "discourse/ui-kit/d-breadcrumbs-container";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.showBreadcrumbs}}
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
        @label={{i18n "admin.plugins.title"}}
      />
      {{#if @controller.currentLegacyPlugin}}
        <DBreadcrumbsItem
          @route={{@controller.currentLegacyPlugin.adminRoute.full_location}}
          @label={{@controller.currentLegacyPlugin.nameTitleized}}
        />
      {{/if}}
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
