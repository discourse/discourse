import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";
import FormKitSiteSettingWrapper from "admin/components/form-kit-site-setting-wrapper";

export default RouteTemplate(
  <template>
    {{#if @controller.filteredSiteSettings}}
      <section class="form-horizontal settings">
        <FormKitSiteSettingWrapper
          @settings={{@controller.filteredSiteSettings}}
        />

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
