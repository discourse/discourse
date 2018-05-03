import DashboardTable from "admin/components/dashboard-table";
import AsyncReport from "admin/mixins/async-report";

export default DashboardTable.extend(AsyncReport, {
  layoutName: "admin/templates/components/dashboard-table",

  classNames: ["dashboard-table", "dashboard-table-trending-search"]
});
