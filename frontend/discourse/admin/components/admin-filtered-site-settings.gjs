import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import AdminSiteSettingsFilterControls from "discourse/admin/components/admin-site-settings-filter-controls";
import SiteSetting from "discourse/admin/components/site-setting";
import SiteSettingFilter from "discourse/admin/lib/site-setting-filter";
import PluginOutlet from "discourse/components/plugin-outlet";
import discourseDebounce from "discourse/lib/debounce";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import { i18n } from "discourse-i18n";

export default class AdminFilteredSiteSettings extends Component {
  @service adminSiteSettingStore;

  @tracked matchedGroups;
  @tracked activeFilter = "";
  @tracked onlyOverridden = false;
  @tracked loading = true;

  siteSettingFilter = new SiteSettingFilter(this.args.settings);

  constructor() {
    super(...arguments);
    this.filterChanged({ filter: "", onlyOverridden: false });
  }

  get visibleGroups() {
    return (this.matchedGroups ?? [])
      .map((group) => ({
        ...group,
        titled: group.nameKey !== "all_results" && !this.isFiltering,
        siteSettings: group.siteSettings.filter((setting) =>
          this.adminSiteSettingStore.isVisible(setting, this.activeFilter)
        ),
      }))
      .filter((group) => group.siteSettings.length > 0);
  }

  get isFiltering() {
    return this.activeFilter !== "" || this.onlyOverridden;
  }

  get noResults() {
    return isEmpty(this.visibleGroups) && !this.loading;
  }

  @action
  filterChanged(filterData) {
    this._debouncedOnChangeFilter(filterData);
  }

  filterSettings(filterData) {
    this.args.onFilterChanged(filterData);
    this.activeFilter = filterData.filter ?? "";
    this.onlyOverridden = !!filterData.onlyOverridden;
    this.matchedGroups = this.siteSettingFilter.filterSettings(
      filterData.filter,
      {
        includeAllCategory: false,
        onlyOverridden: filterData.onlyOverridden,
        dependsOn: filterData.dependsOn,
      }
    );
    this.loading = false;
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

  <template>
    <PluginOutlet @name="admin-config-area-filtered-site-settings">
      <AdminSiteSettingsFilterControls
        @initialFilter={{@initialFilter}}
        @onChangeFilter={{this.filterChanged}}
      />

      <DConditionalLoadingSpinner @condition={{this.loading}}>
        <section class="admin-filtered-site-settings form-horizontal settings">
          {{#each this.visibleGroups key="nameKey" as |group|}}
            {{#if group.titled}}
              <div class="form-kit__section-header">
                <h2 class="form-kit__section-title">
                  {{group.name}}
                </h2>
              </div>
            {{/if}}

            {{#each group.siteSettings as |setting|}}
              <SiteSetting @formKitRows={{@formKitRows}} @setting={{setting}} />
            {{/each}}
          {{/each}}

          {{#if this.noResults}}
            {{i18n "admin.site_settings.no_results"}}
          {{/if}}
        </section>
      </DConditionalLoadingSpinner>
    </PluginOutlet>
  </template>
}
