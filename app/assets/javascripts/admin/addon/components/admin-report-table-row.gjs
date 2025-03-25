import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";

@tagName("tr")
@classNames("admin-report-table-row")
export default class AdminReportTableRow extends Component {
  options = null;
}

{{#each this.labels as |label|}}
  <AdminReportTableCell
    @label={{label}}
    @data={{this.data}}
    @options={{this.options}}
  />
{{/each}}