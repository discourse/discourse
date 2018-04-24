import DashboardTable from "admin/components/dashboard-table";
import { number } from 'discourse/lib/formatter';

export default DashboardTable.extend({
  layoutName: "admin/templates/components/dashboard-table",

  classNames: ["dashboard-table", "dashboard-table-trending-search"],

  transformModel(model) {
    return {
      labels: model.labels,
      values: model.data.map(data => {
        return [data[0], number(data[1]), number(data[2])];
      })
    };
  },
});
