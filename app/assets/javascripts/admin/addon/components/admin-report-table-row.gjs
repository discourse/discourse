import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import AdminReportTableCell from "admin/components/admin-report-table-cell";

@tagName("tr")
@classNames("admin-report-table-row")
export default class AdminReportTableRow extends Component {
  options = null;

  <template>
    {{#each this.labels as |label|}}
      <AdminReportTableCell
        @label={{label}}
        @data={{this.data}}
        @options={{this.options}}
      />
    {{/each}}
  </template>
}
