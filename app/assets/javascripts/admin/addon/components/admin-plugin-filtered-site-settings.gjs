import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { inject as service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import SiteSettingFilter from "discourse/lib/site-setting-filter";
import discourseDebounce from "discourse-common/lib/debounce";
import AdminSiteSettingsFilterControls from "admin/components/admin-site-settings-filter-controls";
import SiteSetting from "admin/components/site-setting";

export default class AdminPluginFilteredSiteSettings extends Component {
  @service currentUser;
  @tracked visibleSettings;
  @tracked loading = true;

  siteSettingFilter = new SiteSettingFilter(this.args.settings);

  constructor() {
    super(...arguments);
    this.filterChanged({ filter: "", onlyOverridden: false });
  }

  filterSettings(filterData) {
    this.visibleSettings = this.siteSettingFilter.filterSettings(
      filterData.filter,
      {
        includeAllCategory: false,
        onlyOverridden: filterData.onlyOverridden,
      }
    )[0]?.siteSettings;
    this.loading = false;
  }

  @action
  filterChanged(filterData) {
    this._debouncedOnChangeFilter(filterData);
  }

  _debouncedOnChangeFilter(filterData) {
    cancel(this.onChangeFilterHandler);
    this.onChangeFilterHandler = discourseDebounce(
      this,
      this.filterSettings,
      filterData,
      200
    );
  }

  <template>
    <AdminSiteSettingsFilterControls @onChangeFilter={{this.filterChanged}} />

    <ConditionalLoadingSpinner @condition={{this.loading}}>
      <section class="form-horizontal settings">
        {{#each this.visibleSettings as |setting|}}
          <SiteSetting @setting={{setting}} />
        {{/each}}
      </section>
    </ConditionalLoadingSpinner>
  </template>
}
