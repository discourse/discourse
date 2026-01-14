import SiteSetting from "discourse/admin/components/site-setting";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.filteredSiteSettings}}
    <section class="form-horizontal settings">
      {{#each @controller.filteredSiteSettings as |setting|}}
        <SiteSetting @setting={{setting}} />
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
