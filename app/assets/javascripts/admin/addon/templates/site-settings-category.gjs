import RouteTemplate from "ember-route-template";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";
import SiteSetting from "admin/components/site-setting";

export default RouteTemplate(
  <template>
    {{#if @controller.filteredContent}}
      <section class="form-horizontal settings">
        {{#each @controller.filteredContent as |setting|}}
          <SiteSetting
            @setting={{setting}}
            @afterSave={{routeAction "refreshAll"}}
          />
        {{/each}}
        {{#if @controller.category.hasMore}}
          <p class="warning">{{i18n
              "admin.site_settings.more_site_setting_results"
              count=@controller.category.maxResults
            }}</p>
        {{/if}}
      </section>
    {{else}}
      <br />
      {{i18n "admin.site_settings.no_results"}}
    {{/if}}
  </template>
);
