import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import SiteSettingFilter from "discourse/lib/site-setting-filter";
import i18n from "discourse-common/helpers/i18n";
import discourseDebounce from "discourse-common/lib/debounce";
import AdminSiteSettingsFilterControls from "admin/components/admin-site-settings-filter-controls";
import SiteSetting from "admin/components/site-setting";

export default class AdminFilteredSiteSettings extends Component {
  @service currentUser;
  @tracked visibleSettings;
  @tracked loading = true;

  siteSettingFilter = new SiteSettingFilter(this.args.settings);

  constructor() {
    super(...arguments);
    this.filterChanged({ filter: "", onlyOverridden: false });
  }

  @action
  filterChanged(filterData) {
    this._debouncedOnChangeFilter(filterData);
  }

  get noResults() {
    return isEmpty(this.visibleSettings) && !this.loading;
  }

  _debouncedOnChangeFilter(filterData) {
    cancel(this.onChangeFilterHandler);
    this.onChangeFilterHandler = discourseDebounce(
      this,
      this.filterSettings,
      filterData,
      100
    );
  }

  filterSettings(filterData) {
    this.args.onFilterChanged(filterData);
    this.visibleSettings = this.siteSettingFilter.filterSettings(
      filterData.filter,
      {
        includeAllCategory: false,
        onlyOverridden: filterData.onlyOverridden,
      }
    )[0]?.siteSettings;
    this.loading = false;
  }

  <template>
    <AdminSiteSettingsFilterControls
      @onChangeFilter={{this.filterChanged}}
      @initialFilter={{@initialFilter}}
    />

    <ConditionalLoadingSpinner @condition={{this.loading}}>
      <section class="admin-filtered-site-settings form-horizontal settings">
        {{#each this.visibleSettings as |setting|}}
          <SiteSetting @setting={{setting}} />
        {{/each}}

        {{#if this.noResults}}
          {{i18n "admin.site_settings.no_results"}}
        {{/if}}
      </section>
    </ConditionalLoadingSpinner>
  </template>
}
