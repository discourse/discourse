import { i18n } from "discourse-i18n";
import AdminHolidaysListItem from "./admin-holidays-list-item";

const AdminHolidaysList = <template>
  <table class="d-table admin-holidays-list">
    <thead class="d-table__header">
      <tr class="d-table__row">
        <th class="d-table__header-cell">{{i18n "discourse_calendar.date"}}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_calendar.holiday"
          }}</th>
        <th></th>
      </tr>
    </thead>
    <tbody class="d-table__body">
      {{#each @holidays as |holiday|}}
        <AdminHolidaysListItem
          @holiday={{holiday}}
          @isHolidayDisabled={{holiday.disabled}}
          @regionCode={{@regionCode}}
        />
      {{/each}}
    </tbody>
  </table>
</template>;

export default AdminHolidaysList;
