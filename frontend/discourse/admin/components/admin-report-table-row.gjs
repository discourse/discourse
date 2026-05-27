/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import AdminReportTableCell from "discourse/admin/components/admin-report-table-cell";

@tagName("")
export default class AdminReportTableRow extends Component {
  options = null;

  <template>
    <tr class="admin-report-table-row" ...attributes>
      {{#each this.labels as |label|}}
        <AdminReportTableCell
          @label={{label}}
          @data={{this.data}}
          @options={{this.options}}
        />
      {{/each}}
    </tr>
  </template>
}
