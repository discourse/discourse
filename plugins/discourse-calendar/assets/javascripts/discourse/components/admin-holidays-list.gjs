import { i18n } from "discourse-i18n";
import AdminHolidaysListItem from "./admin-holidays-list-item";

const AdminHolidaysList = <template>
  <table class="holidays-list">
    <thead>
      <tr>
        <td>{{i18n "discourse_calendar.date"}}</td>
        <td colspan="2">{{i18n "discourse_calendar.holiday"}}</td>
      </tr>
    </thead>

    <tbody>
      {{#each @holidays as |holiday|}}
        <AdminHolidaysListItem
          @holiday={{holiday}}
          @isHolidayDisabled={{holiday.disabled}}
          @region_code={{@region_code}}
        />
      {{/each}}
    </tbody>
  </table>
</template>;

export default AdminHolidaysList;
