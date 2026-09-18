import AdminReportTableCell from "discourse/admin/components/admin-report-table-cell";

const AdminReportTableRow = <template>
  <tr class="admin-report-table-row" ...attributes>
    {{#each @labels as |label|}}
      <AdminReportTableCell
        @data={{@data}}
        @hasRelatedItems={{@hasRelatedItems}}
        @label={{label}}
        @options={{@options}}
        @reportFilters={{@reportFilters}}
        @reportType={{@reportType}}
      />
    {{/each}}
  </tr>
</template>;

export default AdminReportTableRow;
