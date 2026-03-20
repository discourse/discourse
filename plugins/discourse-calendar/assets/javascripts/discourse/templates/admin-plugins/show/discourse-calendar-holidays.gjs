import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import AdminHolidaysList from "discourse/plugins/discourse-calendar/discourse/components/admin-holidays-list";
import RegionInput from "discourse/plugins/discourse-calendar/discourse/components/region-input";

export default <template>
  <DBreadcrumbsItem
    @path="/admin/plugins/discourse-calendar/holidays"
    @label={{i18n "discourse_calendar.holidays.header_title"}}
  />

  <div class="calendar-admin-holidays admin-detail">
    <DPageSubheader
      @titleLabel={{i18n "discourse_calendar.holidays.header_title"}}
      @descriptionLabel={{i18n
        "discourse_calendar.holidays.header_description"
      }}
    />

    <RegionInput
      @value={{@controller.selectedRegion}}
      @onChange={{@controller.getHolidays}}
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
