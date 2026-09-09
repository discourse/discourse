import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import AdminHolidaysList from "discourse/plugins/discourse-events/discourse/components/admin-holidays-list";
import RegionInput from "discourse/plugins/discourse-events/discourse/components/region-input";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "discourse_events.holidays.header_title"}}
    @path="/admin/plugins/discourse-events/holidays"
  />

  <div class="calendar-admin-holidays admin-detail">
    <DPageSubheader
      @descriptionLabel={{i18n "discourse_events.holidays.header_description"}}
      @titleLabel={{i18n "discourse_events.holidays.header_title"}}
    />

    <RegionInput
      @onChange={{@controller.getHolidays}}
      @value={{@controller.selectedRegion}}
    />

    <DConditionalLoadingSpinner @condition={{@controller.loading}} />

    {{#if @controller.holidays}}
      <AdminHolidaysList
        @holidays={{@controller.holidays}}
        @regionCode={{@controller.selectedRegion}}
      />
    {{/if}}
  </div>
</template>
