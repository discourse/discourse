import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";
import AdminHolidaysList from "discourse/plugins/discourse-calendar/discourse/components/admin-holidays-list";
import RegionInput from "discourse/plugins/discourse-calendar/discourse/components/region-input";

export default RouteTemplate(
  <template>
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

      <ConditionalLoadingSpinner @condition={{@controller.loading}} />

      {{#if @controller.holidays}}
        <AdminHolidaysList
          @holidays={{@controller.holidays}}
          @regionCode={{@controller.selectedRegion}}
        />
      {{/if}}
    </div>
  </template>
);
